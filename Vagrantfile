# vi: set ft=ruby :

NAME = 'turing.example.org'.freeze

def setup_virtualbox(config)
  config.vm.box = 'ubuntu/xenial64'
  config.vm.define NAME
  config.vm.network 'private_network', type: 'dhcp'

  config.vm.provider 'virtualbox' do |vb|
    vb.memory = '2048'
  end
end

def configure_digitalocean(provider, api_token)
  provider.token = api_token
  provider.image = 'ubuntu-14-04-x64'
  provider.region = 'nyc3'
  provider.size = '1gb'
end

def setup_digitalocean(config, api_token)
  config.vm.define NAME do |cfg|
    cfg.vm.provider :digital_ocean do |provider, override|
      override.ssh.private_key_path = 'spec/assets/id_rsa'
      override.vm.box = 'digital_ocean'
      override.vm.box_url = 'https://github.com/devopsgroup-io/vagrant-digitalocean/raw/master/box/digital_ocean.box'
      configure_digitalocean provider, api_token
    end
  end
end

Vagrant.configure('2') do |config|
  if ENV.key? 'DIGITAL_OCEAN_API_TOKEN'
    setup_digitalocean config, ENV['DIGITAL_OCEAN_API_TOKEN']
  else
    setup_virtualbox config
  end

  config.vm.provision 'shell', path: 'bootstrap/bootstrap.sh'
  config.vm.provision 'shell', path: 'bootstrap/vagrant.sh'
end
