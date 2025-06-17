#!/bin/bash

# Trap exit method in case of exit while running initial sync.
clean_quit()
{
  if [ ! -f "$LOG_FILE_PATH" ]; then 
    touch "$LOG_FILE_PATH" 
  fi
  echo "Received exit signal, stopping MetaDB Instance" >> $LOG_FILE_PATH
  if [ -f "$DATA_DIR/metadb.pid" ]; then
    sudo -u metadb /usr/bin/metadb stop -D "$DATA_DIR"
  fi
  exit
}

trap clean_quit SIGHUP SIGINT SIGQUIT SIGABRT SIGTERM

ORIGINAL_METADB_RUN_MODE=$METADB_RUN_MODE

# Script Start
echo "Testing if $DATA_DIR exists" >> /proc/1/fd/1

# Check if DATA_DIR exists, if not then runs metadb init
INIT_FLAG="false"
if [ ! -d "$DATA_DIR" ]; then
  echo "$DATA_DIR does NOT exist, starting initialization process" >> /proc/1/fd/1
  mkdir -p "$DATA_DIR"
  rm -r "$DATA_DIR"
  /usr/bin/metadb init -D "$DATA_DIR" >> /proc/1/fd/1
  chown -R metadb "$DATA_DIR"
  INIT_FLAG="true"
fi

if [ -f "$LOG_FILE_PATH" ]; then
  if [ -f "${LOG_FILE_PATH}.old" ]; then
    cat "$LOG_FILE_PATH" >> "${LOG_FILE_PATH}.old"
    rm -f "$LOG_FILE_PATH"
  else
    mv "$LOG_FILE_PATH" "${LOG_FILE_PATH}.old"
  fi
fi

# Ensures the metadb user has access to write to log
if [ ! -f "$LOG_FILE_PATH" ]; then
  touch "$LOG_FILE_PATH"
  chown metadb "$LOG_FILE_PATH"
  echo "Created Log File at $LOG_FILE_PATH" >> /proc/1/fd/1
fi

# Copy all log entries from the log file to the STDOUT of PID 1, so it appears in docker logs
tail -f "$LOG_FILE_PATH" >> /proc/1/fd/1 &

# Make sure MetaDB doesn't accidentally run a task multiple times due to the container restarting unexpectedly.
if [ -f "$DATA_DIR/.error-flag" ]; then
  if [ "$METADB_RUN_MODE" = "start" ]; then
    rm -f "$DATA_DIR/.error-flag"
  else
    echo "MetaDB exited with an error with the METADB_RUN_MODE in a task-state (sync, endsync, upgrade). In order to prevent tasks from unintentionally running multiple times, this script will exit with an error code. To clear this error state, either delete the file at $DATA_DIR/.error-flag or start MetaDB with METADB_RUN_MODE set to 'start'." >> "$LOG_FILE_PATH"
    sleep 5
    exit 1
  fi
fi

if [ -f "$DATA_DIR/metadb.pid" ]; then
  rm -f "$DATA_DIR/metadb.pid"
fi

# Generate metadb.conf
if [ -f "$DATA_DIR/metadb.conf" ]; then
  rm -f "$DATA_DIR/metadb.conf"
  echo 'Deleting metadb.conf file' >> "$LOG_FILE_PATH"
fi

echo 'Generating new metadb.conf file' >> "$LOG_FILE_PATH"
touch "$DATA_DIR/metadb.conf"
chown -R metadb "$DATA_DIR"
chmod o-rwx "$DATA_DIR/metadb.conf"
echo "[main]
host = $BACKEND_DB_HOST
port = $BACKEND_DB_PORT
database = $BACKEND_PG_DATABASE
superuser = $BACKEND_PG_SUPERUSER
superuser_password = $BACKEND_PG_SUPERUSER_PASSWORD
systemuser = $BACKEND_PG_USER
systemuser_password = $BACKEND_PG_USER_PASSWORD
sslmode = $BACKEND_PG_SSLMODE" > "$DATA_DIR/metadb.conf"

# Create Data Source Object if Initializing new MetaDB Instance
if [ "$INIT_FLAG" = "true" ]; then
  echo 'Continuing initialization process' >> "$LOG_FILE_PATH"
  if [ "$VERBOSE_LOGGING" = "true" ]; then
    sudo -u metadb /usr/bin/metadb start -D "$DATA_DIR" -l "$LOG_FILE_PATH" --port $METADB_PORT --debug --memlimit $MEM_LIMIT_GB &
  fi
  if [ "$VERBOSE_LOGGING" = "false" ]; then
    sudo -u metadb /usr/bin/metadb start -D "$DATA_DIR" -l "$LOG_FILE_PATH" --port $METADB_PORT --memlimit $MEM_LIMIT_GB &
  fi
  echo 'Registering Kafka Connector' >> "$LOG_FILE_PATH"
  sleep 5

  if [[ "$ADD_SCHEMA_PREFIX" == *"_" ]] && ! [[ "$FOLIO_TENANT_NAME" == *"_" ]]; then
    FOLIO_TENANT_NAME="${FOLIO_TENANT_NAME}_"
  fi
  if ! [[ "$ADD_SCHEMA_PREFIX" == *"_" ]] && [[ "$FOLIO_TENANT_NAME" == *"_" ]]; then
    ADD_SCHEMA_PREFIX="${ADD_SCHEMA_PREFIX}_"
  fi

  psql -X -h localhost -d metadb -p $METADB_PORT -c "CREATE DATA SOURCE sensor TYPE kafka OPTIONS (brokers '$KAFKA_BROKERS', module 'folio', trim_schema_prefix '$FOLIO_TENANT_NAME', topics '$KAFKA_TOPICS', consumer_group '$KAFKA_CONSUMER_GROUP', add_schema_prefix '$ADD_SCHEMA_PREFIX', schema_stop_filter '$SCHEMA_STOP_FILTER', security '$KAFKA_SECURITY');"
  echo 'Running initial synchronization with Kafka Connect sensor (this may take awhile). Once the sync is complete ("source snapshot complete" will appear in the log file), MetaDB will run with METADB_RUN_MODE set to "endsync".' >> "$LOG_FILE_PATH"
  
  INIT_SYNC_FLAG=0
  while [ $INIT_SYNC_FLAG -le 0 ]
  do
    INIT_SYNC_FLAG=$(cat "$LOG_FILE_PATH" | grep "snapshot complete" | wc -l)
    sleep 1
  done

  echo 'Initial snapshot completed' >> "$LOG_FILE_PATH"

  sudo -u metadb /usr/bin/metadb stop -D "$DATA_DIR"
  METADB_RUN_MODE="endsync"
fi

# Run MetaDB
if [ "$METADB_RUN_MODE" = "upgrade" ]; then
  if [ "$INIT_FLAG" = "true" ]; then
    echo 'ERROR: MetaDB is set to run in upgrade mode, but it is just now initializing? Change METADB_RUN_MODE to "start"' >> "$LOG_FILE_PATH"
    touch "$DATA_DIR/.error-flag"
    exit 1
  fi
  echo 'Starting MetaDB Upgrade Task (this may take awhile)' >> "$LOG_FILE_PATH"
  exec sudo -u metadb /usr/bin/metadb upgrade -D "$DATA_DIR" --force 2>&1 | cat >> "$LOG_FILE_PATH"
  echo 'MetaDB Upgrade Complete! Running MetaDB with METADB_RUN_MODE variable set to "start". Recommended to change the METADB_RUN_MODE variable value to "start" and restarting the container when convenient.' >> "$LOG_FILE_PATH"
  METADB_RUN_MODE="start"
fi

if [ "$METADB_RUN_MODE" = "sync" ]; then
  if [ "$INIT_FLAG" = "true" ]; then
    echo 'ERROR: MetaDB is set to run in sync mode, but it is just now initializing? Change METADB_RUN_MODE to "start"' >> "$LOG_FILE_PATH"
    touch "$DATA_DIR/.error-flag"
    exit 1
  fi
  echo 'Starting MetaDB Sync Task (source: sensor)' >> "$LOG_FILE_PATH"
  if [ "$FORCE_RUN" = "true" ]; then
    exec sudo -u metadb /usr/bin/metadb sync -D "$DATA_DIR" --source sensor --force 2>&1 | cat >> "$LOG_FILE_PATH"
  else
    exec sudo -u metadb /usr/bin/metadb sync -D "$DATA_DIR" --source sensor 2>&1 | cat >> "$LOG_FILE_PATH"
  fi
  echo 'MetaDB Sync Complete! Running MetaDB with METADB_RUN_MODE variable set to "endsync".' >> "$LOG_FILE_PATH"
  METADB_RUN_MODE="endsync"
fi

if [ "$METADB_RUN_MODE" = "endsync" ]; then
  echo 'Starting MetaDB Endsync Task (source: sensor)' >> "$LOG_FILE_PATH"
  if [ "$FORCE_RUN" = "true" ]; then
    exec sudo -u metadb /usr/bin/metadb endsync -D "$DATA_DIR" --source sensor --force 2>&1 | cat >> "$LOG_FILE_PATH"
  else
    exec sudo -u metadb /usr/bin/metadb endsync -D "$DATA_DIR" --source sensor 2>&1 | cat >> "$LOG_FILE_PATH"
  fi
  echo 'MetaDB Endsync Complete! Running MetaDB with METADB_RUN_MODE variable set to "start". Recommended to change the METADB_RUN_MODE variable value to "start" and restarting the container when convenient.' >> "$LOG_FILE_PATH"
  METADB_RUN_MODE="start"
fi

if [ "$METADB_RUN_MODE" = "migrate" ]; then
  echo "Starting MetaDB migration from LDP using configuration file ${LDP_CONF_FILE_PATH}." >> "$LOG_FILE_PATH"
  exec sudo -u metadb /usr/bin/metadb migrate -D "$DATA_DIR" --ldpconf "$LDP_CONF_FILE_PATH" --source sensor 2>&1 | cat >> "$LOG_FILE_PATH"
  echo 'MetaDB migration from LDP complete. Running MetaDB with METADB_RUN_MODE variable set to "start". Recommended to change the METADB_RUN_MODE variable value to "start" and restarting the container when convenient.' >> "$LOG_FILE_PATH"
  METADB_RUN_MODE="start"
fi

if [ "$METADB_RUN_MODE" = "start" ]; then
  echo 'Starting MetaDB Instance' >> "$LOG_FILE_PATH"
  if [ "$VERBOSE_LOGGING" = "true" ]; then
    exec sudo -u metadb /usr/bin/metadb start -D "$DATA_DIR" -l "$LOG_FILE_PATH" --port $METADB_PORT --debug --memlimit $MEM_LIMIT_GB
  fi
  if [ "$VERBOSE_LOGGING" = "false" ]; then
    exec sudo -u metadb /usr/bin/metadb start -D "$DATA_DIR" -l "$LOG_FILE_PATH" --port $METADB_PORT --memlimit $MEM_LIMIT_GB
  fi
fi

if ! [ "$ORIGINAL_METADB_RUN_MODE" = "start" ]; then
  echo "MetaDB exited unexpectedly with the METADB_RUN_MODE not set to 'start'. Setting error flag at $DATA_DIR/.error-flag" >> "$LOG_FILE_PATH"
  touch "$DATA_DIR/.error-flag"
fi
