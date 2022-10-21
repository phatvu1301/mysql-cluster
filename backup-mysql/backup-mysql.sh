#!/bin/bash
DB="superset"
DUMP_FILE="/opt/campaignx/docker/backup_bi/$DB-export-$(date +"%Y%m%d%H%M%S").sql"
CREDENTIALS="--defaults-extra-file=credentials.cnf"
LOOP_BORDER=$(printf "%30s")
MYSQL_EXEC=$(docker ps -aqf "name=^cpx_mysql")
BI_EXEC=$(docker ps -aqf "name=^cpx_superset")
CHECK_BI=$(docker ps -aq --filter "name=^cpx_superset" --filter "health=healthy")

function backup {
    HOST_NAME=$(docker exec $MYSQL_EXEC cat /etc/hostname)
    docker exec -it $MYSQL_EXEC mysqldump $CREDENTIALS -h $HOST_NAME --dump-date $MYSQL_DATABASE >$DUMP_FILE
}

function restore {
    if [[ -z $1 ]]; then
        echo "Please provide date to restore. Example 20220601"
    else
        DATA_RESTORE=$(ls -t /opt/campaignx/docker/backup_bi/ | grep $1 | head -n 1)
        HOST_NAME=$(docker exec $MYSQL_EXEC cat /etc/hostname)
        if [[ -z $DATA_RESTORE ]]; then
            echo "No data to Restore"
        else
            docker exec -it $MYSQL_EXEC mysql $CREDENTIALS -h $HOST_NAME -e "DROP DATABASE IF EXISTS $MYSQL_DATABASE; CREATE DATABASE $MYSQL_DATABASE;"
            sleep 15
            echo ${LOOP_BORDER// /=}
            echo "Restoring latest data dump of $2 to Database superset"
            docker exec -it $MYSQL_EXEC mysql $CREDENTIALS -h $HOST_NAME $MYSQL_DATABASE < /opt/campaignx/docker/backup_bi/$DATA_RESTORE
            echo "Restore done to Database superset"
            echo ${LOOP_BORDER// /=}
            while [ -z "$CHECK_BI" ]; do
                echo "Waiting Superset first healthy"
                sleep 5
            done
            echo "Migrate Database for superset"
            docker exec -it $BI_EXEC superset db upgrade
            echo "Upgrade role for superset"
            docker exec -it $BI_EXEC superset init
        fi
    fi
}

case "$1" in
backup)
    backup
    ;;
restore)
    restore $2
    ;;
*)
    echo "Please use '"backup"' / '"restore date"' to run me "
    ;;
esac

