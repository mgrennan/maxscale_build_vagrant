import '/vagrant/puppet-config.pp'

$homedir         = '/home/vagrant'
$srcdir          = "$homedir/maxscale"

Exec {
  path        => [ '/bin/', '/sbin/' , '/usr/bin/', '/usr/sbin/' ],
  environment => [ "HOME=$homedir" ],
  cwd         => "$srcdir",
}

file { '/etc/motd':
  content => 'SkySQL MaxScale build/test instance'
}


#
# OS specific preparations
#

$arch = $architecture ? {
  /^.*86$/ => 'x86',
  /^.*64$/ => 'amd64',
  default => $architecture,  
}

case $operatingsystem {

  'centos': {
    # CentOS has no equivalent to the build-essential deb package
    # and puppet doesn't support yum groups yet (?)
    # so we do things the manual way with 'exec' here ... 
    exec { 'dev-tools':
      unless  => '/usr/bin/yum grouplist "Development tools" | /bin/grep "^Installed Groups"',
      command => '/usr/bin/yum -y groupinstall "Development tools"',
    }
    $dev_tool_req = Exec["dev-tools"] 

    # CentOS 6.4 doesn't have MariaDB in its repository out of the box
    # so we need to register the MariaDB.org yum repository first
    yumrepo { 'mariadb':
      descr => 'MariaDB Yum Repo',
      enabled => 1,
      gpgcheck => 1,
      gpgkey => 'https://yum.mariadb.org/RPM-GPG-KEY-MariaDB',
      baseurl => "http://yum.mariadb.org/5.5/centos6-${arch}",
    }

    # OS specific package names
    $pkg_libssl_dev     = "openssl-devel"
    $pkg_libaio_dev     = "libaio-devel"

    # embedded server lib is part of MariaDB-dev, no extra pkg needed here
    $pkg_libmariadb_req = ''

    # install MariaDB server
    package { 'mariadb-server':  
      ensure => present, 
      name => "MariaDB-server", 
      require => Yumrepo['mariadb'], 
    }

    # install client library dev package (includes embedded server library)
    package{ 'MariaDB-devel': 
      ensure => present, 
      require => Yumrepo['mariadb'], }
    $mariadb_dev_req = Package['MariaDB-devel']
  }

  'ubuntu': {
    # enforce up-to-date package list before installing packages
    exec { 'apt-update':
      command => '/usr/bin/apt-get update',
      cwd     => '/tmp',
    }
    Exec['apt-update'] -> Package <| |>

    # here we have a build-essential meta package, so no extra hacks
    # required as with yum groups above
    package {'build-essential': ensure => present, }
    $dev_tool_req = Package["build-essential"] 

    # mariadb packages are in Ubuntu Trusty alrady, no extra repo needed
    $repo_maria = ''

    # OS specific package names
    $pkg_libssl_dev = "libssl-dev"
    $pkg_libaio_dev = "libaio-dev"
  
    # install MariaDB server
    package { 'mariadb-server':  ensure => present, }

    # client and embedded server lib dev packages
    package {'libmariadbclient-dev': ensure => present}
    package {'libmariadbd-dev': ensure => present}
    $mariadb_dev_req = Package['libmariadbclient-dev', 'libmariadbd-dev']
  }

}

#
# packages required for gettig the source 
#

package { 'git':             ensure => present, }
package { 'patch':           ensure => present, }

#
# stuff useful for debugging
#

# install GNU debugger
package { 'gdb':             ensure => present, }


# enable core dumps
include ulimit
ulimit::rule {
  'coresize':
    ulimit_domain => '*',
    ulimit_type   => 'soft',
    ulimit_item   => 'core',
    ulimit_value  => 'unlimited';
}

# 
# some extra libraries that we need
#

package { 'libssl-dev':      ensure => present, name => $pkg_libssl_dev, }
package { 'libaio-dev':      ensure => present, name => $pkg_libaio_dev, }

#
# checking out the source
#

vcsrepo { "maxscale_git":
  ensure   => 'latest',
  path     => $srcdir,
  require  => [Package['git']],
  provider => 'git',
  source   => $git_repo,
  revision => $git_branch,
  user     => 'vagrant',
  owner    => 'vagrant',
  group    => 'users',
}

#
# build_gateway.inc and test.inc may need some tweaking
#

exec { "patch_build_gateway_inc":
  require =>  [ Vcsrepo["maxscale_git"], Package["patch"] ],
  command => "patch -p1 < /vagrant/puppet/files/build_gateway.inc.patch",
  onlyif  => "grep -q bazaar build_gateway.inc", 
}

exec { "patch_test_inc":
  require =>  [ Vcsrepo["maxscale_git"], Package["patch"] ],
  command => "patch -p1 < /vagrant/puppet/files/test.inc.patch",
  onlyif  => "grep -q 'THOST           := $' test.inc", 
}

#
# run "make depend" first
#

exec { "make_depend":
  require => [ Exec['patch_build_gateway_inc']
             , Exec['patch_test_inc']
	     , $dev_tool_req
	     , $mariadb_dev_req
             ],
  command => "make depend",
}

#
# then build with just "make"
#

exec { "make":
  require => Exec["make_depend"],
  command => "make",
}

#
# install what we've built in /usr/local/skysql
#

exec { "make_install":
  require => Exec["make"],
  command => "make install; chown -R vagrant .",
  user    => "root",
  environment => ["DEST=/usr/local"],
}

#
# RPM/APT start a single mysqld after installation, we don't need that one
#

service { "mysql":
  require => Package["mariadb-server"],
  ensure => stopped,
}

#
# now start the multi mysqld setup we need
#

exec { "start_test_servers":
  require => Service["mysql"],
  command => "/vagrant/puppet/files/multi-servers.sh",
  user    => "root",
}

#
# TODO: "make testall" should go here, but doesn't really seem to work yet
#       so for now run it manually within the VM 
#
