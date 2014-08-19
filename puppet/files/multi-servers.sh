#! /bin/bash

OPTS="--defaults-file=/vagrant/puppet/files/my.cnf"

# ensure mysql installation basedir exists and is writable
mkdir -p /usr/local/mysql
chown mysql:mysql /usr/local/mysql

# we start a total of 3 mysqld servers
for n in 1 2 3
do 
  # was the db datadir initialized already?
  if test -f /usr/local/mysql/var$n/mysql/user.frm
  then
    # just start the mysqld server
    mysqld_multi $OPTS start $n
  else
    # initialize databse
    mysql_install_db --user=mysql --datadir=/usr/local/mysql/var$n >/dev/null

    # start the mysqld server
    mysqld_multi $OPTS start $n

    # wait for mysqld server to start up
    while ! mysqladmin --socket=/tmp/mysql$n.sock ping 2>/dev/null
    do
	sleep 1;
    done

    # create MaxScale test user
    mysql --socket=/tmp/mysql$n.sock -e 'GRANT ALL ON *.* to maxuser@127.0.0.1 IDENTIFIED BY "maxpwd" WITH GRANT OPTION '

    # all but the first mysqld are slaves to the first one
    if test $n -gt 1 
    then
	mysql --socket=/tmp/mysql$n.sock -e 'CHANGE MASTER TO MASTER_HOST="127.0.0.1", MASTER_PORT=3000, MASTER_USER="maxuser", MASTER_PASSWORD="maxpwd"'
	mysql --socket=/tmp/mysql$n.sock -e 'START SLAVE'
    fi
  fi
done


