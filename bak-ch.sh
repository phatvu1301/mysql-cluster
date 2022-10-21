#!/bin/bash

CH_EXEC=$(docker ps -qf "name=^cpx_ch_agg")
HOST_NAME=$(docker exec $CH_EXEC cat /etc/hostname)
BACKUP_NAME=$HOST_NAME-$(date -u +%Y-%m-%dT%H-%M-%S)
BACKUP_CF_DIR="/etc/clickhouse-server/config.d/config-backup.yml"
function backup {
    echo "Logs backup in directory /opt/campaignx/docker/clickhouse-agg/logs/clickhouse-backup.log"
    echo "Backup stored in /opt/campaignx/docker/clickhouse-agg/data/backup and /opt/campaignx/docker/clickhouse-agg/data/shadow"
    docker exec -it $CH_EXEC clickhouse-backup create -c $BACKUP_CF_DIR $BACKUP_NAME >>/opt/campaignx/docker/clickhouse-agg/logs/clickhouse-$HOST_NAME-backup.log
    if [[ $? != 0 ]]; then
        echo "clickhouse-backup create $BACKUP_NAME FAILED and return $? exit code"
    fi
}

function list-backup {
    docker exec -it $CH_EXEC clickhouse-backup list -c $BACKUP_CF_DIR
}

function delete-backup {
    if [[ -z $1 ]]; then
        echo "Please provide backup name"
    else
        echo "Logs delete backup in directory /opt/campaignx/docker/clickhouse-agg/logs/clickhouse-backup.log"
        docker exec -it $CH_EXEC clickhouse-backup delete -c $BACKUP_CF_DIR local "$1" >>/opt/campaignx/docker/clickhouse-agg/logs/clickhouse-$HOST_NAME-delete-backup.log
    fi
}

function restore-backup {
    if [[ -z $1 ]]; then
        echo "Please provide backup name"
    else
        echo "Restoring backup $1 ..."
        docker exec -it $CH_EXEC clickhouse-backup restore -c $BACKUP_CF_DIR "$1" >>/opt/campaignx/docker/clickhouse-agg/logs/clickhouse-$HOST_NAME-restore-backup.log
    fi
}

case "$1" in
backup)
    backup
    ;;
list-backup)
    list-backup
    ;;
delete-backup)
    delete-backup $2
    ;;
restore-backup)
    restore-backup $2
    ;;
*)
    echo "Please use '"backup"' / '"list-backup"' / '"delete-backup"' / '"restore-backup"' to run me "
    ;;
esac
