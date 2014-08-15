#! /bin/bash

for n in 1 2 3
do 
  if ! test -f /usr/local/mysql/var$n/mysql/user.frm
  then
    mysql_install_db --user=mysql --datadir=/usr/local/mysql/var$n >/dev/null
    mysqld_multi --defaults-file=/vagrant/puppet/files/my.cnf start $n

    while ! mysqladmin --socket=/tmp/mysql$n.sock ping 2>/dev/null
    do
	sleep 1;
    done

    mysql --socket=/tmp/mysql$n.sock -e 'GRANT ALL ON *.* to maxuser@127.0.0.1 IDENTIFIED BY "maxpwd"'

    if test $n -gt 1 
    then
	mysql --socket=/tmp/mysql$n.sock -e 'CHANGE MASTER TO MASTER_HOST="127.0.0.1", MASTER_PORT=3000, MASTER_USER="maxuser", MASTER_PASSWORD="maxpwd"'
	mysql --socket=/tmp/mysql$n.sock -e 'START SLAVE'
    fi
  else
    mysqld_multi --defaults-file=/vagrant/puppet/files/my.cnf start $n
  fi
done


