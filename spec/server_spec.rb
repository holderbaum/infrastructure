require 'spec_helper'
require 'net/http'

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

  it 'should serve content' do
    response = Net::HTTP.get_response(external_ip, '/index.html')
    expect(response.code).to eq('200')
  end

  it 'should enable certbot challenges' do
    challenge_key = 'YYYCT5-SxWTOd1ZJCI-jCEFwdAfavJublNB--RR0kac'
    path = '/.well-known/acme-challenge/' + challenge_key

    response = Net::HTTP.get_response(external_ip, path)
    expect(response.body).to eq('test-challenge')
  end
end
