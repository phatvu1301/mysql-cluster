#!/bin/bash
mysql_dirs="/var/lib/mysql /var/lib/mysql-files /var/lib/mysql-keyring /var/run/mysqld"

for dir in $mysql_dirs; do
    mkdir -p $dir
    chmod g+rwx $dir
    chgrp -R 0 $dir
done