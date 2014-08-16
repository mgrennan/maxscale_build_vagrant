$mariadb_version = 'mariadb-5.5.35'
$git_repo        = 'https://github.com/skysql/MaxScale.git'
$git_branch      = 'release-1.0beta'

$homedir         = '/home/vagrant'
$srcdir          = "$homedir/maxscale"

file { '/etc/motd':
  content => 'SkySQL MaxScale build/test instance'
}

Exec {
  path        => [ '/bin/', '/sbin/' , '/usr/bin/', '/usr/sbin/' ],
  environment => [ "HOME=$homedir" ],
  cwd         => "$srcdir",
}

$arch = $architecture ? {
  /^.*86$/ => 'x86',
  /^.*64$/ => 'amd64',
  default => $architecture,  
}

include ulimit

ulimit::rule {
  'coresize':
    ulimit_domain => '*',
    ulimit_type   => 'soft',
    ulimit_item   => 'core',
    ulimit_value  => 'unlimited';
}

# OS specific preparations
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

    # CentOS 6.4 have MariaDB in its repository out of the box
    yumrepo { 'mariadb':
      descr => 'MariaDB Yum Repo',
      enabled => 1,
      gpgcheck => 1,
      gpgkey => 'https://yum.mariadb.org/RPM-GPG-KEY-MariaDB',
      baseurl => "http://yum.mariadb.org/5.5/centos6-${arch}",
    }

    # embedded server lib is part of MariaDB-dev, no extra pkg needed here
    $pkg_libmariadb_req = ''

    # OS specific package names
    $pkg_libssl_dev     = "openssl-devel"
    $pkg_libaio_dev     = "libaio-devel"
    $pkg_mariadb_server = "MariaDB-server"

    package { 'mariadb-server':  
      ensure => present, 
      name => "MariaDB-server", 
      require => Yumrepo['mariadb'], 
    }

    package{ 'MariaDB-devel': ensure => present, }
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

    # mariadb packages are in Ubuntu Trusty alrady
    $repo_maria = ''

    # OS specific package names
    $pkg_libssl_dev = "libssl-dev"
    $pkg_libaio_dev = "libaio-dev"
  
    package { 'mariadb-server':  ensure => present, }

    package {'libmariadbclient-dev': ensure => present}
    package {'libmariadbd-dev': ensure => present}
    $mariadb_dev_req = Package['libmariadbclient-dev', 'libmariadbd-dev']
  }

}
 
package { 'git':             ensure => present, }
package { 'patch':           ensure => present, }
package { 'gdb':             ensure => present, }

package { 'libssl-dev':      ensure => present, name => $pkg_libssl_dev, }
package { 'libaio-dev':      ensure => present, name => $pkg_libaio_dev, }

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

exec { "patch_after_checkout":
  require =>  [ Vcsrepo["maxscale_git"], Package["patch"] ],
  command => "patch -p1 < /vagrant/puppet/files/patch.txt",
  onlyif  => "grep -q bazaar build_gateway.inc", 
}

exec { "make_depend":
  require => [ Exec['patch_after_checkout']
	     , $dev_tool_req
	     , $mariadb_dev_req
             ],
  command => "make depend",
}

exec { "make":
  require => Exec["make_depend"],
  command => "make",
}

exec { "make_install":
  require => Exec["make"],
  command => "make install",
  user    => "root",
  environment => ["DEST=/usr/local"],
}

service { "mysql":
  require => Package["mariadb-server"],
  ensure => stopped,
}

exec { "start_test_servers":
  require => Service["mysql"],
  command => "/vagrant/puppet/files/multi-servers.sh",
  user    => "root",
}

