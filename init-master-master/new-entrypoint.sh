#!/bin/bash

# Outputs the contents with replaced environment variables
HOST_NAME=$(cat /etc/hostname)
function replace_env {
        while read line
        do
                if [[ ${line:0:1} == '#' ]]; then
                        echo $line
                else
                        eval echo "$line"
                fi
        done < $1
}

# sleep 10
echo "Generating /etc/mysql/conf.d/custom-$HOSTNAME.cnf :"
echo '========================================='
replace_env custom.cnf.tmp | tee /etc/mysql/conf.d/custom-$HOSTNAME.cnf
echo '========================================='


chmod 644 /etc/mysql/conf.d/custom-*

echo 'Generating Credentials :'
echo '========================================='
replace_env credentials.cnf.tmp | tee ./credentials.cnf
echo '========================================='


bash replication-start.sh $INIT_FROM_MASTER 127.0.0.1 &
exec /entrypoint.sh "$@"