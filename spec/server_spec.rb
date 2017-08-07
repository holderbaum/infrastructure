require 'spec_helper'

describe port(22) do
  it { should be_listening }
end

describe service('ufw') do
  it { should be_running }
end
