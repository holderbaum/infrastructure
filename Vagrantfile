# vi: set ft=ruby :

Vagrant.configure('2') do |config|
  unless ENV.key? 'DIGITAL_OCEAN_API_TOKEN'
    puts 'Missing DIGITAL_OCEAN_API_TOKEN'
    exit 1
  end

  config.vm.define 'turing.example.org'
  config.vm.box = 'digital_ocean'
  config.vm.box_url = 'https://github.com/smdahlen/vagrant-digitalocean/raw/master/box/digital_ocean.box'
  config.ssh.private_key_path = './tmp/test_rsa_id'

  config.vm.provider :digital_ocean do |digital_ocean|
    digital_ocean.token = ENV['DIGITAL_OCEAN_API_TOKEN']
    digital_ocean.ssh_key_name = 'Vagrant ' + Time.now.to_s
    digital_ocean.image = 'ubuntu-16-04-x64'
    digital_ocean.region = 'fra1'
    digital_ocean.size = 'c-2'
  end

  config.vm.synced_folder '.', '/vagrant', disabled: true

  config.vm.provision 'shell', path: 'bootstrap/bootstrap.sh'
end
