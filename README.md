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

Requirements
------------

Recent versions of:

* Vagrant (I tested with version 1.6.2 only, but I think anything >= 1.4 will do)
* Virtualbox >= 4.0 (i used version 4.3.10)

Vagrant configuration
---------------------

The vagrant configuration is pretty straight forward,
you may choose between using a CentOS or Ubunto base
box by uncommenting the appropriate config block
(CentOS being enabled by default).

All other settings should be fine as is.

There is optional support for the Vagrant Cachier
plugin ( http://fgrehm.viewdocs.io/vagrant-cachier )
which will speed up provisioning if you tear down
and recreate a VM as it transparently caches RPM / APT 
packages, but everything will work fine without
that plugin being installed, too.

Puppet configuration
--------------------

The only things that needs to be configured are the
GIT repository and branch to fetch source from in
puppet-config.pp.

The actual puppet manifest is in puppet/manifests/base.pp,
it takes care of 

* installing all necessary packages, 
* enabling core dumps
* checking out MaxScale source
* building and installing MaxScale
* starting and configuring three mysqld instances in 
  a master/slave setup suitable for running the bundled tests

Running the tests is not part of the process yet as I think
that this should be done manually and output should be watched.

Test setup
----------

After a successful "vagrant up" there are three running
mysqld instances:

* a master on port 3000 / socket /tmp/mysql1.sock
* a slave on port 3001 / socket /tmp/mysql2.sock
* a 2nd slave on port 3002 / socket /tmp/mysql3.sock

The three servers share the same my.cnf file from puppet/files,
the mysqld_multi tool is used to start the three instances
with settings from the appropriate my.cnf sections.

A user "maxuser" with password "maxpwd" and full privileges
has been created on all three mysqld instances, and the two
slaves are replicationg from the master.

These settings match the default test configuration.

Testing
-------

After the test VM has been brought up with 

* vagrant up

you can log into it with 

* vagrant ssh

In the VM shell move to the maxscale source directory

* cd maxscale

then run the test suite with

* make testall

After completion you will find testserver.log and
a log subdir with maxscale daemon logs in the server/test
directory.