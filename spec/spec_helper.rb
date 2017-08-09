require 'serverspec'
require 'net/ssh'
require 'tempfile'

set :backend, :ssh

host = 'turing.example.org'

config = Tempfile.new('', Dir.tmpdir)
config.write(`vagrant ssh-config #{host}`)
config.close

options = Net::SSH::Config.for(host, [config.path])

options[:paranoid] = false

set :host,        options[:host_name] || host
set :host,        options[:port]
set :ssh_options, options
