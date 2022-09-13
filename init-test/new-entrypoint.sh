#!/bin/bash

# Outputs the contents with replaced environment variables
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

if [[ $INIT_MASTER_IP_4SLAVE ]]; then
        sleep 20
        echo 'Generating /etc/mysql/conf.d/custom.cnf :'
        echo '========================================='
        replace_env custom.cnf.slave.template | tee /etc/mysql/conf.d/custom.cnf
        echo '========================================='
else
        echo 'Generating /etc/mysql/conf.d/custom.cnf :'
        echo '========================================='
        replace_env custom.cnf.template | tee /etc/mysql/conf.d/custom.cnf
        echo '========================================='
fi

chmod 644 '/etc/mysql/conf.d/custom.cnf'

echo 'Generating /app/credentials.cnf :'
echo '========================================='
replace_env credentials.cnf.template | tee credentials.cnf
echo '========================================='

if [[ ! -z "$INIT_MASTER_IP_4SLAVE" ]]; then
    bash ./replication-start.sh $INIT_MASTER_IP_4SLAVE 127.0.0.1 &
#     echo $INIT_MASTER_IP_4SLAVE 
fi

# Call the parent image entrypoint
# exec /entrypoint.sh "$@"