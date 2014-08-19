# -*- mode: ruby -*-
# vi: set ft=ruby :

VAGRANTFILE_API_VERSION = "2"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  config.vm.hostname = "maxscale-build.local"

  ### uncomment for CentOS 6.4 VM
  config.vm.box = "centos_6_4_amd64"
  config.vm.box_url = "http://developer.nrel.gov/downloads/vagrant-boxes/CentOS-6.4-x86_64-v20131103.box"

  ### uncomment for Ubunutu Trusty VM
  # config.vm.box = "trusty_amd64"
  # config.vm.box_url = "https://cloud-images.ubuntu.com/vagrant/trusty/current/trusty-server-cloudimg-amd64-vagrant-disk1.box"

  config.vm.provider :virtualbox do |vb|
    vb.name = "maxscale_build_vm"

    vb.memory = 1024
    vb.cpus = 2

    # fix vagrant/virtualbox DNS issues
    vb.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
  end

  config.vm.provision :puppet do |puppet|
    puppet.manifests_path = "puppet/manifests"
    puppet.module_path    = "puppet/modules"
    puppet.manifest_file  = "base.pp"
  end

  # RPM/.den package cacher
  # see http://fgrehm.viewdocs.io/vagrant-cachier
  if Vagrant.has_plugin?("vagrant-cachier")
    config.cache.scope = :box
  end

end
