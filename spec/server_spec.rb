require 'spec_helper'
require 'English'
require 'xmpp4r'
require 'net/smtp'
require 'net/imap'
require 'net/pop'

HAD_FAILURE = false

describe 'infrastructure' do
  before(:all) do
    setup_ssh_backend
    setup_fake_hosts [
      'xmpp.example.org',
      'mail.example.org',
      'blog.example.org'
    ]
  end

  after(:each) do |example|
    HAD_FAILURE = true if example.exception
  end

  after(:all) do
    if HAD_FAILURE
      journal = `ssh -F tmp/ssh-config turing.example.org journalctl -b`
      puts 'Saved test machine journal:'
      puts journal
    end
  end

  describe 'ssh' do
    it 'should be reachable' do
      wait_for { port 22 }.to be_listening.with 'tcp'
    end
  end

  describe 'automatic updates' do
    describe package('unattended-upgrades') do
      it { should be_installed }
    end

    describe file('/etc/apt/apt.conf.d/50unattended-upgrades') do
      it { should be_file }
      its(:content) do
        should match(/^        "\${distro_id}:\${distro_codename}-security";$/)
      end
    end
  end

  describe service('ufw') do
    it { should be_running }
  end

  describe 'sharing' do
    it 'should allow ssh access' do
      ssh_cmd = ['ssh',
                 '-F tmp/ssh-config',
                 '-i ./spec/assets/id_rsa',
                 'sharing-images@turing.example.org'].join ' '
      `#{ssh_cmd} exit 2>/dev/null`

      expect($CHILD_STATUS).to eq(0)
    end

    describe file('/data/sharing/images') do
      it { should be_directory }
      it { should be_mode 750 }
    end

    describe command('unison -version') do
      its(:stdout) { should match(/2.48.4/) }
    end
  end

  describe 'xmpp' do
    let(:host) { 'xmpp.example.org' }
    let(:user) { 'testuser' }
    let(:pass) { 'testpass' }

    before do
      Jabber.debug = false
    end

    it 'should be reachable for c2s' do
      wait_for { port 5222 }.to be_listening.with 'tcp'
    end

    it 'should be reachable for c2c' do
      wait_for { port 5269 }.to be_listening.with 'tcp'
    end

    it 'should do proper starttls' do
      # openssl s_client
      #   -connect 172.28.128.3:5222
      #   -starttls xmpp
      #   -xmpphost xmpp.example.org
      #   </dev/null
    end

    it 'should allow login' do
      jid = Jabber::JID.new "#{user}@#{host}"
      client = Jabber::Client.new jid
      client.connect
      client.auth pass
    end

    it 'should deny unauthorized connections' do
      jid = Jabber::JID.new "#{user}@#{host}"
      client = Jabber::Client.new jid
      client.connect
      expect do
        client.auth_anonymous
      end.to raise_error(Jabber::ClientAuthenticationFailure)
    end

    it 'should deny registrations' do
      jid = Jabber::JID.new "#{user}2@#{host}"
      client = Jabber::Client.new jid
      client.connect
      expect do
        client.register pass
      end.to raise_error(Jabber::ServerError)
    end
  end

  describe 'ssl' do
    describe file('/data/certificates/test.example.org/privkey.pem') do
      it { should be_file }
      it { should be_mode 440 }
    end

    describe file('/etc/cron.d/certbot_renew_test_example_org') do
      its(:content) { should contain('MAILTO=user-cron@example.org') }
      its(:content) do
        expected_job = ['@weekly',
                        'certbot',
                        '/usr/local/bin/obtain-or-renew-certificate.sh',
                        "'test.example.org'"].join ' '
        should contain(expected_job)
      end
    end
  end

  describe 'www' do
    it 'should be reachable' do
      wait_for { port 80 }.to be_listening.with 'tcp'
    end

    it 'should redirect to https' do
      response = get "http://#{external_ip}/foo/"
      expect(response.status).to be(301)
      location = response.headers['location']
      expect(location).to contain("https://#{external_ip}/foo/")
    end

    it 'should enable certbot challenges' do
      challenge_key = 'YYYCT5-SxWTOd1ZJCI-jCEFwdAfavJublNB--RR0kac'
      path = '/.well-known/acme-challenge/' + challenge_key

      response = get "http://#{external_ip}#{path}"
      expect(response.status).to be(200)
      expect(response.body).to contain('test-challenge')
    end
  end

  describe 'static sites' do
    let(:host) { 'blog.example.org' }

    it 'should redirect to https' do
      response = get 'http://blog.example.org/foo/bar'
      expect(response.status).to be(301)
      location = response.headers['location']
      expect(location).to contain('https://blog.example.org/foo/bar')
    end

    it 'should allow for uploading' do
      content = "test page #{rand 1000}"

      html_file = Tempfile.create
      html_file.write(content)
      html_file.close

      ssh_cmd = ['ssh',
                 '-F tmp/ssh-config',
                 '-i ./spec/assets/id_rsa'].join ' '
      rsync_cmd = ['rsync',
                   '-r',
                   "-e '#{ssh_cmd}'",
                   '--chmod 640',
                   html_file.path,
                   'deploy-blog@turing.example.org:www/index.html'].join ' '
      `#{rsync_cmd}`

      response = get_no_verify 'https://blog.example.org/'
      expect(response.status).to be(200)
      expect(response.body).to contain(content)
    end
  end

  describe 'mail' do
    let(:user) { 'jakob@example.org' }
    let(:pass) { 'test' }

    describe 'retrieving' do
      it 'should deny login over plain imap' do
        imap = Net::IMAP.new('mail.example.org')

        expected_error = Net::IMAP::NoResponseError
        expected_message = /Plaintext authentication disallowed/

        expect do
          imap.login user, pass
        end.to raise_error expected_error, expected_message
      end

      it 'should allow login over plain imap via starttls' do
        imap = Net::IMAP.new 'mail.example.org'
        imap.starttls '', false
        imap.login user, pass
      end

      it 'should allow login over TLS imap' do
        imap = Net::IMAP.new('mail.example.org',
                             ssl: {
                               verify_mode: OpenSSL::SSL::VERIFY_NONE
                             })
        imap.login user, pass
      end

      it 'should deny login over plain pop3' do
        pop = Net::POP3.new 'mail.example.org'

        expected_error = Net::POPAuthenticationError
        expected_message = /Plaintext authentication disallowed/

        expect do
          pop.start user, pass
        end.to raise_error expected_error, expected_message
      end

      it 'should be able to do starttls over plain pop3' do
        cmd = ['echo DONE |',
               'openssl s_client',
               '-starttls pop3',
               "-connect #{external_ip}:110",
               '-servername mail.example.org',
               '-verify_return_error',
               '2>&1']

        output = `#{cmd.join(' ')}`

        expect($CHILD_STATUS).to be_success
        expect(output).to match(/^\+OK Dovecot ready\.\r\n/)
      end

      it 'should allow login over TLS pop3' do
        pop = Net::POP3.new 'mail.example.org'
        pop.enable_ssl verify_mode: OpenSSL::SSL::VERIFY_NONE
        pop.start user, pass
        pop.finish
      end
    end

    describe 'receiving' do
      it 'should accept mail to known mailbox' do
        body = 'a test mail ' + rand(1000).to_s
        send_mail 'jakob@example.org', body
        expected = fetch_newest_mail_body('jakob@example.org', 'test')
        expect(expected).to contain(body)

        body = 'another test mail ' + rand(1000).to_s
        send_mail 'jakob@bar.com', body
        expected = fetch_newest_mail_body('jakob@bar.com', 'otherpw')
        expect(expected).to contain(body)
      end

      it 'should accept mail to known mailbox with suffix' do
        body = 'a test mail ' + rand(1000).to_s
        send_mail 'jakob+foo@example.org', body
        expected = fetch_newest_mail_body('jakob@example.org', 'test')
        expect(expected).to contain(body)
      end

      it 'should accept mail to alias at same domain' do
        body = 'a test mail ' + rand(1000).to_s
        send_mail 'alias@example.org', body
        expected = fetch_newest_mail_body('jakob@example.org', 'test')
        expect(expected).to contain(body)
      end

      it 'should accept mail to alias at different domain' do
        body = 'a test mail ' + rand(1000).to_s
        send_mail 'test@foo.com', body
        expected = fetch_newest_mail_body('jakob@example.org', 'test')
        expect(expected).to contain(body)
      end

      it 'should not accept mail to unknown mailbox' do
        expected_error = Net::SMTPFatalError
        expected_message = /unknown/

        expect do
          send_mail 'unknown@example.org', 'unknown mailbox'
        end.to raise_error expected_error, expected_message
      end

      it 'should not accept mail to unknown alias mailbox' do
        expected_error = Net::SMTPFatalError
        expected_message = /unknown/

        expect do
          send_mail 'unknown@foo.com', 'unknown mailbox'
        end.to raise_error expected_error, expected_message
      end

      describe file('/data/mail/vmail/example.org/jakob/new') do
        it { should be_directory }
      end

      def send_mail(to, body)
        from = 'root@example.com'
        msg = "Subject: Hey!!\n\n#{body}"
        smtp = Net::SMTP.new 'mail.example.org', 2525
        smtp.start('mail.example.org') do
          smtp.send_message(msg, from, to)
        end
      end

      def fetch_newest_mail_body(username, password)
        imap = Net::IMAP.new 'mail.example.org'
        imap.starttls '', false
        imap.login username, password

        imap.examine 'INBOX'
        last_message_id = imap.search(['RECENT']).last

        imap.fetch(last_message_id, 'BODY[TEXT]')[0].attr['BODY[TEXT]']
      end
    end
  end
end
