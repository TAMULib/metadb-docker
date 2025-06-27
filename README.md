# metadb-docker

Contains the build files for https://hub.docker.com/repository/docker/tamulibraries/metadb/

**Current Version:** v1.3.9

The "master" branch of this repo will always contain the build files for the latest image, which is the latest **stable release** from MetaDB. There are currently no plans to support non-stable-release builds of MetaDB, or instances of MetaDB that aren't using [FOLIO](https://folio.org/) as the backend

For feedback/reporting issues on the Dockerfile or the associated Run Script, please use our Github repo (https://github.com/TAMULib/metadb-docker/issues). Please note that we are not the developers of MetaDB, so any issues for the underlying software should be submitted to the developer's github repo (https://github.com/metadb-project/metadb/issues).

# ENVIRONMENT VARIABLES
|        Variable Name        |      DEFAULT VALUE                             |                     VALID OPTIONS                           |                              COMMENTS                             |
|-----------------------------|------------------------------------------------|-------------------------------------------------------------|-------------------------------------------------------------------|
|DATA_PATH                    |      /data/metadb                              |                                                             |Point to where persistent storage is mounted.                      |
|LOG_FILE_PATH                | /data/metadb/metadb.log                        |                                                             |Recommended to keep in persistent storage.                         |
|VERBOSE_LOGGING              |         false                                  |                     true, false                             |                                                                   |
|MEM_LIMIT_GB                 |           2                                    |                                                             |Must be set.                                                       |
|METADB_PORT                  |         8550                                   |                    1024 to 65535                            |Port this container will listen on.                                |
|BACKEND_DB_HOST              |       pg-metadb                                |                                                             |FQDN or k8s Service Name for Postgres backend.                     |
|BACKEND_DB_PORT              |         5432                                   |                    1024 to 65535                            |                                                                   |
|BACKEND_PG_DATABASE          |        metadb                                  |                                                             |Must exist ahead of time.                                          |
|BACKEND_PG_SUPERUSER         |       postgres                                 |                                                             |Not sure if this is needed or not...                               |
|BACKEND_PG_SUPERUSER_PASSWORD|        <null>                                  |                                                             |Not sure if this is needed or not...                               |
|BACKEND_PG_USER              |        metadb                                  |                                                             |Postgres User who must own BACKEND_PG_DATABASE.                    |
|BACKEND_PG_USER_PASSWORD     |        <null>                                  |                                                             |                                                                   |
|BACKEND_PG_SSLMODE           |        prefer                                  |disable, allow, prefer, require, verify-ca, verify-full      |Haven't tested with SSL yet.                                       |
|METADB_RUN_MODE              |        start                                   |        start, upgrade, sync, endsync, migrate               |Read MetaDB docs linked below.                                     |
|KAFKA_BROKERS                |      kafka:9092                                |                                                             |Use comma-separated list for multiple brokers.                     |
|KAFKA_TOPICS                 |   ^metadb_sensor_1\.                           |                                                             |Kafka topics that MetaDB will watch.                               |
|KAFKA_CONSUMER_GROUP         |   metadb_sensor_1_1                            |                                                             |Kafka Consumer Group that MetaDB creates/joins.                    |
|SCHEMA_STOP_FILTER           |         admin                                  |                                                             |Schemas that MetaDB explicitly won't ingest.                       |
|KAFKA_SECURITY               |       plaintext                                |                    plaintext, ssl                           |Haven't tested with SSL yet.                                       |
|ADD_SCHEMA_PREFIX            |        sensor_                                 |                                                             |Prepends value to schemas in analytics DB.                         |
|FOLIO_TENANT_NAME            |          tamu                                  |                                                             |Name of the tenant in FOLIO this will monitor.                     |
|LDP_CONF_FILE_PATH           |  /ldpconf/ldpconf.json                         |                                                             |Only needed for "migrate" task. ConfigMap Recommended.             |
|DERIVED_TABLES_GIT_REPO      |https://github.com/folio-org/folio-analytics.git|URL pointing to any valid git repo.                          |Must be public, must contain 'sql_metadb/derived_tables' folders.  |
|DERIVED_TABLES_GIT_REFS       |     refs/tags/v1.8.0                           |Any exisiting tag/branch in repo, or blank to disable.|Tag from DERIVED_TABLES_GIT_REPO to clone to run daily.            |
|FORCE_RUN                    |          false                                 |                      true. false                            |Force sync and endsync tasks to ALWAYS proceed.                    |
|SQL_INIT_SCRIPT_PATH         |     /scripts/mappings.sql                      |Valid file path OR empty. Mounted ConfigMap recommended.     |SQL file run during init process. Include data mappings here.      |

DockerHub: https://hub.docker.com/repository/docker/tamulibraries/metadb

MetaDB Github: https://github.com/metadb-project/metadb

MetaDB Documentation: https://metadb.dev/doc/1.3/
