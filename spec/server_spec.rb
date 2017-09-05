require 'spec_helper'
require 'xmpp4r'
require 'net/smtp'

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

  describe service('ufw') do
    it { should be_running }
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
    it 'should accept mail' do
      msg = "Subject: Hi There!\n\nThis works."
      from = 'root@example.org'
      to = 'root@example.org'
      smtp = Net::SMTP.new 'mail.example.org', 25
      smtp.start('mail.example.org') do
        smtp.send_message(msg, from, to)
      end
    end
  end
end
