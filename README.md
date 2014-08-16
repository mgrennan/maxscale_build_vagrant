maxscale_build_vagrant
======================

Build / test setup for MaxScale

Requires Vagrant and Virtualbox installed on local system.

To setup just change into the project directory and run "vagrant up".

First time this will take quite a while as it has to fetch a Ubuntu Trusty base box ...

The included puppet manifest will take care of:

* installing all necessary packages
* check out current master branch from github 
  repository url and branch name can be changed in puppet/manifest/base.pp
* tweak build_gateway.inc and test.inc
* running "make depend", "make" and "make instal"
* starting a test mysqld master and two slaves

You can then log into the virtual machine with "vagrant ssh", 
MaxScale source is in the "maxscale" directory once you're
on the virtual machine ...

The setup currently supports both Ubuntu 14.04 'Trusty' and CentOS 6.4.
You can select the appropriate VM image by editing Vagrantfile
