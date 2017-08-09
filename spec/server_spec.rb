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
end
