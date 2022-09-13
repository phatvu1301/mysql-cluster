DB=$MYSQL_DATABASE
DUMP_FILE="/tmp/$DB-export-$(date +"%Y%m%d%H%M%S").sql"

USER=root
PASS=$MYSQL_ROOT_PASSWORD
LOOP_BORDER=$(printf "%30s");

CREDENTIALS="--defaults-extra-file=credentials.cnf"

MASTER_HOST="$1"
shift
SLAVE_HOSTS=("$@")

# Wait for mysql to be running, in case of auto-init during container startup
if [[ $INIT_MASTER_IP_4SLAVE ]]; then
	# sleep 20
	sleep 20
fi

##
# MASTER
# ------
# Export database and read log position from master, while locked
##
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
echo "Connection maded to $MASTER_HOST"