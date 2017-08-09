require 'serverspec'
require 'net/ssh'
require 'tempfile'

set :backend, :ssh

host = 'turing.example.org'

config = Tempfile.new('', Dir.tmpdir)
config.write(`vagrant ssh-config #{host}`)
config.close

options = Net::SSH::Config.for(host, [config.path])
set :ssh_options, options

def external_ip
  @external_ip ||= `vagrant ssh -c "hostname -I |cut -d' ' -f2" 2>/dev/null`
end
