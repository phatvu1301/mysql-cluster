DB=$MYSQL_DATABASE
DUMP_FILE="/tmp/$DB-export-$(date +"%Y%m%d%H%M%S").sql"

USER=root
PASS=$MYSQL_ROOT_PASSWORD
#CREDENTIALS="-u$USER -p$USER"
CREDENTIALS="--defaults-extra-file=credentials.cnf"

MASTER_HOST="$1"
shift
SLAVE_HOSTS=("$@")

# Wait for mysql to be running, in case of auto-init during container startup
if [[ $AUTO_INIT_MASTER_IP ]]; then
        sleep 20
fi

##
# MASTER
# ------
# Export database and read log position from master, while locked
##

echo "MASTER: $MASTER_HOST"

# Wait till we can login on Master so we know DB setup is done
echo "Trying to login to $MASTER_HOST"

while ! mysql $CREDENTIALS -h $MASTER_HOST -e ";"; do
        echo "No connection can be made to $MASTER_HOST. trying again in 10"
        sleep 10
done


# Run these mysql commands in background
mysql $CREDENTIALS -h $MASTER_HOST <<-EOSQL &
        GRANT REPLICATION SLAVE ON *.* TO '$USER'@'%' IDENTIFIED BY '$PASS';
        FLUSH PRIVILEGES;
        FLUSH TABLES WITH READ LOCK;
        DO SLEEP(3600);
EOSQL

echo "  - Waiting for database to be locked"
sleep 3
# Take command to unlock after sleep
mysql $CREDENTIALS -h $MASTER_HOST -ANe "UNLOCK TABLES;"

# Dump the database (to the client executing this script) while it is locked
echo "  - Dumping database to $DUMP_FILE"
mysqldump $CREDENTIALS -h $MASTER_HOST --opt --all-databases > $DUMP_FILE
echo "  - Dump complete."

# Take note of the master log position at the time of dump
MASTER_STATUS=$(mysql $CREDENTIALS -h $MASTER_HOST -ANe "SHOW MASTER STATUS;" | awk '{print $1 " " $2}')

echo "Take note of the master log position at the time of dump"
echo "$MASTER_STATUS"

LOG_FILE=$(echo $MASTER_STATUS | cut -f1 -d ' ')
# LOG_FILE=$(mysql $CREDENTIALS -h $MASTER_HOST -ANe "SHOW MASTER STATUS;" | awk '{print $1}')
# LOG_POS=$(mysql $CREDENTIALS -h $MASTER_HOST -ANe "SHOW MASTER STATUS;" | awk '{print $2}')
LOG_POS=$(echo $MASTER_STATUS | cut -f2 -d ' ')
echo "  - Current log file is $LOG_FILE and log position is $LOG_POS"

# When finished, kill the background locking command to unlock

echo "$!"
kill $! 2>/dev/null
wait $! 2>/dev/null

echo "  - Master database unlocked"

##
# SLAVES
# ------
# Import the dump into slaves and activate replication with
# binary log file and log position obtained from master.
##

for SLAVE_HOST in "${SLAVE_HOSTS[@]}"
do
        echo "SLAVE: $SLAVE_HOST"
        echo "  - Creating database copy"
        #mysql $CREDENTIALS -h $SLAVE_HOST -e "DROP DATABASE IF EXISTS $DB; CREATE DATABASE $DB;"
        if [ ! -z "$AUTO_INIT_MASTER_IP" ]; then
                scp $DUMP_FILE $SLAVE_HOST:$DUMP_FILE >/dev/null
        fi
        mysql $CREDENTIALS -h $SLAVE_HOST $DB < $DUMP_FILE
        #mysql $CREDENTIALS -h $SLAVE_HOST < $DUMP_FILE

        echo "  - Setting up slave replication"
        #mysql $CREDENTIALS -h $SLAVE_HOST <<-EOSQL
        mysql $CREDENTIALS -h $SLAVE_HOST $DB <<-EOSQL
                STOP SLAVE;
                CHANGE MASTER TO MASTER_HOST='$MASTER_HOST',
                MASTER_USER='$USER',
                MASTER_PASSWORD='$PASS',
                MASTER_LOG_FILE='$LOG_FILE',
                MASTER_LOG_POS=$LOG_POS;
                START SLAVE;
        EOSQL

        # Wait for slave to get started and have the correct status
        sleep 2
        # Check if replication status is OK
        SLAVE_OK=$(mysql $CREDENTIALS -h $SLAVE_HOST -e "SHOW SLAVE STATUS\G;" | grep 'Waiting for master')
        if [ -z "$SLAVE_OK" ]; then
                echo "  - Error ! Wrong slave IO state."
        else
                echo "  - Slave IO state OK"
        fi
done