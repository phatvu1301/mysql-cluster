#!/bin/bash
# main server process is started
if [ -f /var/lib/mysql-files/mysql-init-complete ]; # The entrypoint script touches this file
then # Ping server to see if it is ready
  mysqladmin --defaults-extra-file=/var/lib/mysql-files/healthcheck.cnf ping
else # Initialization still in progress
  exit 1
fi