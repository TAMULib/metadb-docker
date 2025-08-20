# metadb-docker

**Current Version:** v1.4.0

Contains the build files for https://hub.docker.com/r/tamulibraries/metadb/tags

The "master" branch of this repo will always contain the build files for the latest image, which is the latest **stable release** from MetaDB. Currently the image only supports MetaDB instances which are using [FOLIO](https://folio.org/) as the backend.

For feedback/reporting issues on anything within this repo (Dockerfile, run-metadb.sh script, minor changes to MetaDB source code with modify-code.sh), please use [the 'Issues' feature of our Github repository](https://github.com/TAMULib/metadb-docker/issues). Please note that **we are not the developers of MetaDB**, so any issues for the underlying software should be submitted to [the developer's Github repository](https://github.com/metadb-project/metadb/issues).

It is recommended to run a single MetaDB instance for each FOLIO tenant. Any other configuration is unsupported.

# Requirements
- Postgres 15 (or later) Database
    - For Postgres configuration, make sure `wal_level = logical`, as well as the [recommended configuration options from the MetaDB developer](https://metadb.dev/doc/1.3/#_postgresql_configuration).
    - A backend user (BACKEND_PG_USER) and a database (BACKEND_PG_DATABASE) must already exist. It ia highly recommended to make the backend user the owner of the backend database.
    - CPU usage on top peaks out around 4.00 during nightly maintenance jobs.
    - At least 8GB of shared memory is required. 12-16GB is recommended.
    - Initial disk usage is approximately 2x the size of the source database, so it is recommended to give the analytics database around 5x the disk size of the source database.
-  Kafka Stack (recommended with Zookeeper)
    - Recommended persistent storage size for Kafka Brokers is 3x the size of the source database. This will be necessary during the initial sync.
    - Make sure log retention is set very liberally. Most databases take at least 24 hours to sync with MetaDB, so it is recommended to set log retention to at least 48 hours and with a very high (or preferably non-existent) byte size limit. If you encounter issues with the initial sync not capturing all of your data, then this is most likely the issue.
    - Recommended to have at least 8GB of memory allocated to each broker.
-  [Debezium Kafka Connector](https://hub.docker.com/r/debezium/connect)
    - Proven to work on v2.7.3 and v3.0.0, will likely continue working as expected in future versions.
    - See [the JSON configuration template from the MetaDB developer.](https://metadb.dev/doc/1.3/#_creating_a_connector). **IMPORTANT:** the `"snapshot.mode": "exported"` is obsolete. Replace it with `"snapshot.mode": "initial"`.
    - Recommended to allocate at least 16GB of memory to this.
    - BOOTSTRAP_SERVERS in the Kafka Connector container should be the same as KAFKA_BROKERS in the MetaDB container.
    - If you have issues with messages exceeding the maximum size, there are several steps you must take:
    - In the Kafka Connector container, set the environment variable `CONNECT_PRODUCER_MAX_REQUEST_SIZE` to above the size of the offending record.
    - In the Kafka Connector container, set the environment variable `CONNECT_MESSAGE_MAX_BYTES` to above the size of the offending record.
    - In the JSON configuration of the Kafka connector, set `producer.override.max.request.size` to above the size of the offending record.
    - In the underlying Kafka stack, set the `message.max.bytes` and/or `KAFKA_CFG_MESSAGE_MAX_BYTES` to above the size of the offending record.
    - Large records often cause the Kafka Connector container to crash and re-start the initial snapshot process. If this happens, you likely need to allocate more memory to the container.

# Setup

There are two ways to setup this container-- with an existing and valid metadb.conf file mounted to the container, or with all of the BACKEND_ environment variables set. Note that the existence of a metadb.conf file at DATA_DIR will completely disable the use of the BACKEND_ environment variables.

**For quick/environment variable setup**, simply populate the following environment variables to match your environment:
- BACKEND_DB_HOST
    - FQDN or k8s Service Name for the Postgres backend, without the port (see BACKEND_DB_PORT).
- BACKEND_PG_USER
    - Name of the Postgres user within the Postgres backend that MetaDB uses to connect to the database.
    - Create this user quickly with this command: `CREATE USER metadb WITH PASSWORD '<PUT PASSWORD HERE>';`
- BACKEND_PG_USER_PASSWORD
    - The password for the BACKEND_PG_USER postgres user.
- BACKEND_PG_DATABASE
    - Name of the database within the Postgres backend. This must already exist and it is recommended to make the BACKEND_PG_USER the owner of this database.
    - Create this database quickly with this command: `CREATE DATABASE metadb WITH OWNER metadb;`
- KAFKA_BROKERS
    - The URL for the Kafka Backend(s). If there are multiple URLs, set the variable as a comma-seperated list. For example 'kafka-broker1.example.org:9092,kafka-broker2.example.org:9092,kafka-broker3.example.org:9092'.
- FOLIO_TENANT_NAME
    - Name of your FOLIO tenant. This will have the effect of changing the name of the table in the source database (such as '<tenant>_mod_inventory_storage') to '<ADD_SCHEMA_PREFIX>_inventory' in the analytics database. To disable this feature, explicitly define this variable as blank (e.g. FOLIO_TENANT_NAME='')

**To mount an existing metadb.conf file**, first create a Secret in Kubernetes with a single entry. The entry's key must be "metadb.conf", and the value must be the contents of the file [as demonstrated here](https://metadb.dev/doc/1.3/#_server_configuration). Then, reconfigure the workload to mount this Secret to wherever you have DATA_DIR set (default: /etc/metadb). Make sure UID 1000 has permission to read this mounted file. To mount other files in the DATA_DIR directory, simply append more entries to this Secret and set the key of the entry to what you want the file to be named. In this setup, it is still recommended to set the following environment variables:
- KAFKA_BROKERS
    - The URL for the Kafka Backend(s). If there are multiple URLs, set the variable as a comma-seperated list. For example 'kafka-broker1.example.org:9092,kafka-broker2.example.org:9092,kafka-broker3.example.org:9092'.
- FOLIO_TENANT_NAME
    - Name of your FOLIO tenant. This will have the effect of changing the name of the table in the source database (such as '<tenant>_mod_inventory_storage') to '<ADD_SCHEMA_PREFIX>_inventory' in the analytics database. To disable this feature, explicitly define this variable as blank (e.g. FOLIO_TENANT_NAME='')

# Environment Variables
|        Variable Name        |      DEFAULT VALUE                             |                     VALID OPTIONS                              |                              COMMENTS                             |
|-----------------------------|------------------------------------------------|----------------------------------------------------------------|-------------------------------------------------------------------|
|DATA_DIR                     |       /etc/metadb                              |Any path writeable to UID 1000.                                 |Point to the folder containing 'metadb.conf', or leave default.    |
|LOG_FILE_PATH                |        <null>                                  |Any path writeable to UID 1000, or empty to disable.            |Recommended to keep in persistent storage.                         |
|VERBOSE_LOGGING              |         false                                  |                     true, false                                |                                                                   |
|MEM_LIMIT_GB                 |           4                                    |                                                                |                                                                   |
|METADB_PORT                  |         8550                                   |                    1024 to 65535                               |Port this container will listen on.                                |
|BACKEND_DB_HOST              |       pg-metadb                                |                                                                |FQDN or k8s Service Name for Postgres backend.                     |
|BACKEND_DB_PORT              |         5432                                   |                    1024 to 65535                               |                                                                   |
|BACKEND_PG_DATABASE          |        metadb                                  |                                                                |Must exist ahead of time.                                          |
|BACKEND_PG_SUPERUSER         |        <null>                                  |                                                                |Optional.                                                          |
|BACKEND_PG_SUPERUSER_PASSWORD|        <null>                                  |                                                                |Optional.                                                          |
|BACKEND_PG_USER              |        metadb                                  |                                                                |Postgres User who must own BACKEND_PG_DATABASE.                    |
|BACKEND_PG_USER_PASSWORD     |        <null>                                  |                                                                |                                                                   |
|BACKEND_PG_SSLMODE           |        prefer                                  |disable, allow, prefer, require, verify-ca, verify-full         |Haven't tested with SSL yet.                                       |
|METADB_RUN_MODE              |        start                                   |        start, upgrade, sync, endsync, migrate                  |Read MetaDB docs linked below.                                     |
|KAFKA_BROKERS                |      kafka:9092                                |                                                                |Use comma-separated list for multiple brokers.                     |
|KAFKA_TOPICS                 |   ^metadb_sensor_1\.                           |                                                                |Kafka topics that MetaDB will watch.                               |
|KAFKA_CONSUMER_GROUP         |   metadb_sensor_1_1                            |                                                                |Kafka Consumer Group that MetaDB creates/joins.                    |
|SCHEMA_STOP_FILTER           |         admin                                  |                                                                |Schemas that MetaDB explicitly won't ingest.                       |
|KAFKA_SECURITY               |       plaintext                                |                    plaintext, ssl                              |Haven't tested with SSL yet.                                       |
|ADD_SCHEMA_PREFIX            |        folio_                                  |                                                                |Optional. Prepends value to schema names in analytics DB.          |
|FOLIO_TENANT_NAME            |          tamu                                  |                                                                |Optional. Removes tenant name from ingested schemas.               |
|LDP_CONF_FILE_PATH           |  /etc/metadb/ldpconf.json                      |                                                                |Only needed for "migrate" task. Mounted Secret Recommended.        |
|DERIVED_TABLES_GIT_REPO      |https://github.com/folio-org/folio-analytics.git|URL pointing to any valid git repo.                             |Must be public, must contain 'sql_metadb/derived_tables' folders.  |
|DERIVED_TABLES_GIT_REFS      |     refs/tags/v1.8.0                           |Any exisiting tag(tags)/branch(heads) in repo. Blank to disable.|Refs from DERIVED_TABLES_GIT_REPO to clone to run daily.           |
|FORCE_RUN                    |          false                                 |                      true. false                               |Force sync and endsync tasks to ALWAYS proceed.                    |
|SQL_INIT_SCRIPT_PATH         |     /etc/metadb/mappings.sql                   |Valid file path OR empty. Mounted ConfigMap recommended.        |SQL file run during init process. Include data mappings here.      |
|SLEEP_AFTER_TASK             |              false                             |                       true, false                              |If true the container stops after a task like upgrade, sync, etc   |

# Derived Tables/Maintenance Jobs

There are two main ways to run Derived Tables jobs against your analytics (BACKEND_) database-- the build-in method and a CronJob. 

The built-in method involves cloning the PUBLIC (private is unsupported) git repo specified with DERIVED_TABLES_GIT_REPO, from the tag or branch specified with DERIVED_TABLES_GIT_REFS. To specify a tag, set DERIVED_TABLES_GIT_REFS to "refs/tags/TAG_NAME_HERE" (replacing TAG_NAME_HERE with the tag name). To specify a branch, set DERIVED_TABLES_GIT_REFS to "refs/heads/BRANCH_NAME_HERE" (replacing BRANCH_NAME_HERE with the name of the branch). The cloned repository MUST contain a folder named "sql_metadb", and inside of that folder there MUST be another folder named "derived_tables", and inside of that folder there MUST be a text file named "runlist.txt". The job works by reading in the "runlist.txt" file one line at-a-time, and running each line in order as a SQL script file against the configured analytics database.

The CronJob method is exactly as it sounds, it is some kind of recurring scheduled task which uses 'psql' and/or third-party postgres clients to read and write to the analytics database. This is not officially supported by this image, but it would certainly work.

# Links
  
DockerHub: https://hub.docker.com/r/tamulibraries/metadb/tags

MetaDB Github: https://github.com/metadb-project/metadb

MetaDB Documentation: https://metadb.dev/doc/1.4/

# Changelog

**v1.4.0**:
- Initial 1.4.0 release version
  
**v1.4.0.rc1-0**:
- Initial 1.4.0-rc1 version