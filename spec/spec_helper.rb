require 'serverspec'
require 'tempfile'
require 'resolv-replace'
require 'tempfile'
require 'faraday'
require 'rspec/wait'

module Helpers
  def setup_ssh_backend
    set :backend, :ssh
    host = 'turing.example.org'

    options = Net::SSH::Config.for(host, ['tmp/ssh-config'])
    @external_ip = options[:host_name]
    set :ssh_options, options
  end

  def external_ip
    @external_ip
  end

  def setup_fake_hosts(hosts)
    fake_hosts = Tempfile.create('hosts')
    File.open(fake_hosts.path, 'w') do |f|
      hosts.each do |host|
        f << "#{external_ip} #{host}\n"
      end
    end

    hosts_resolver = Resolv::Hosts.new(fake_hosts.path)
    dns_resolver = Resolv::DNS.new

    Resolv::DefaultResolver.replace_resolvers([hosts_resolver, dns_resolver])
  end

  def get(url, user = nil, pass = nil)
    http = Faraday.new url
    http.basic_auth user, pass if user && pass
    http.get
  end

  def get_no_verify(url, user = nil, pass = nil)
    http = Faraday.new url, ssl: { verify: false }
    http.basic_auth user, pass if user && pass
    http.get
  end
end

RSpec.configure do |c|
  c.include Helpers
  c.wait_timeout = 60 # seconds
end
