#! /bin/sh
rm -rf `pwd`/modules
mkdir -p `pwd`/modules
OPT=--modulepath=`pwd`/modules
puppet module install puppetlabs-vcsrepo        $OPT
puppet module install arioch-ulimit             $OPT
