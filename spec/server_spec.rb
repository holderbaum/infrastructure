require 'spec_helper'

describe 'infrastructure' do
  before(:all) do
    setup_ssh_backend
    setup_fake_hosts
  end

  after do
    clear_fake_hosts
  end

  describe port(22) do
    it { should be_listening }
  end

  describe service('ufw') do
    it { should be_running }
  end

  describe 'www' do
    describe port(80) do
      it { should be_listening }
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
      register_fake_host external_ip, host

      response = get 'http://blog.example.org/foo/bar'
      expect(response.status).to be(301)
      location = response.headers['location']
      expect(location).to contain('https://blog.example.org/foo/bar')
    end

    it 'should allow for uploading' do
      register_fake_host external_ip, host

      content = "test page #{rand 1000}"

      html_file = Tempfile.create
      html_file.write(content)
      html_file.close

      ssh_cmd = ['ssh',
                 '-o UserKnownHostsFile=/dev/null',
                 '-o StrictHostKeyChecking=no',
                 '-i ./spec/assets/id_rsa'].join ' '
      rsync_cmd = ['rsync',
                   '-r',
                   "-e '#{ssh_cmd}'",
                   '--chmod 640',
                   html_file.path,
                   "deploy-blog@#{external_ip}:www/index.html"].join ' '
      `#{rsync_cmd} 2>/dev/null`

      response = get_no_verify 'https://blog.example.org/'
      expect(response.status).to be(200)
      expect(response.body).to contain(content)
    end
  end
end
