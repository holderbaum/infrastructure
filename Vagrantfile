# vi: set ft=ruby :
Vagrant.configure('2') do |config|
  config.vm.box = 'ubuntu/xenial64'
  # config.vm.box = 'ubuntu/trusty64'

  config.vm.provider 'virtualbox' do |vb|
    vb.memory = '2048'
  end

  config.vm.provision 'shell', path: 'bootstrap/bootstrap.sh'
  config.vm.provision 'shell', path: 'bootstrap/vagrant.sh'
end
