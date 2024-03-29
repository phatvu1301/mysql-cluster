DB=$MYSQL_DATABASE
PASS=$MYSQL_ROOT_PASSWORD
USER=$SL_USER
DUMP_FILE="/tmp/$DB-export-$(date +"%Y%m%d%H%M%S").sql"
HOST_NAME=$(cat /etc/hostname)
LOOP_BORDER=$(printf "%30s");

CREDENTIALS="--defaults-extra-file=credentials.cnf"



MASTER_HOST="$1"
shift
SLAVE_HOSTS=("$@")


function slave_to_master {
	##
	# MASTER
	##
	# Run these mysql commands in background

	mysql $CREDENTIALS -h $MASTER_HOST <<-EOSQL &
			CREATE USER '$USER'@'%' IDENTIFIED BY '$PASS';
			GRANT REPLICATION SLAVE ON *.* TO '$USER'@'%';
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
	LOG_POS=$(echo $MASTER_STATUS | cut -f2 -d ' ')
	echo "  - Current log file is $LOG_FILE and log position is $LOG_POS"

	# When finished, kill the background locking command to unlock

	echo "$!"
	kill $! 2>/dev/null
	wait $! 2>/dev/null

	echo "  - Master database unlocked"

	##
	# SLAVES
	##

	for SLAVE_HOST in "${SLAVE_HOSTS[@]}"
	do
		echo "SLAVE: $SLAVE_HOST"
		echo "  - Creating database copy"
		mysql $CREDENTIALS -h $SLAVE_HOST $DB < $DUMP_FILE

		echo "  - Setting up slave replication"
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
		SLAVE_OK=$(mysql $CREDENTIALS -h $SLAVE_HOST -e "SHOW SLAVE STATUS\G;" | grep 'Waiting for source')
		if [ -z "$SLAVE_OK" ]; then
			echo "  - Error ! Wrong slave IO state."
		else
			echo "  - Slave IO state OK"
		fi
	done
}


echo ${LOOP_BORDER// /=}
echo "I am Slave Node"
echo "MASTER: $MASTER_HOST"
echo ${LOOP_BORDER// /=}


# Wait till we can login on Master so we know DB setup is done
echo "Trying to login to $MASTER_HOST"

while ! mysql $CREDENTIALS -h $MASTER_HOST -e ";"; do
	echo "No connection can be made to $MASTER_HOST. trying again in 10"
	sleep 10
done
echo "Connected to $MASTER_HOST"

# Wait for mysql to be running, in case of auto-init during container startup

if [[ $INIT_CLUSTER ]]; then
	sleep 20
	slave_to_master
	echo $HOST_NAME $MASTER_HOST " - init start"
else
	echo $HOST_NAME $MASTER_HOST " - init none"
	SLAVE_OK_INIT=$(mysql $CREDENTIALS -h $MASTER_HOST -e "SHOW SLAVE STATUS\G;" | grep 'Waiting for source')

	while [ -z "$SLAVE_OK_INIT"  ]; do
	echo "Waiting Slave first init"
	sleep 5
	SLAVE_OK_INIT=$(mysql $CREDENTIALS -h $MASTER_HOST -e "SHOW SLAVE STATUS\G;" | grep 'Waiting for source')
	echo $SLAVE_OK_INIT
	done
	slave_to_master
fi