# metadb-docker

Contains the build files for https://hub.docker.com/layers/tamulibraries/metadb/v1.3.9-hotfix0-UNTESTED/images/sha256-c7cc2e2f3160af83a48956d4f7838d978d7711d854a788a90222a674083ce5c0

**BRANCH IS CURRENTLY BEING TESTED! CVEs ADDRESSED IN THIS BRANCH INCLUDE:**
- CVE-2025-21613
- CVE-2024-45337
- GHSA-9763-4f94-gfch
- CVE-2025-21614
- CVE-2025-22869
- CVE-2025-22874
- CVE-2023-45288
- CVE-2025-22870
- CVE-2025-22872
- CVE-2025-4673
- CVE-2025-0913
- GHSA-2x5j-vhc8-9cwm

**Current Version:** v1.3.9

The "master" branch of this repo will always contain the build files for the latest image, which is the latest **stable release** from MetaDB. There are currently no plans to support non-stable-release builds of MetaDB, or instances of MetaDB that aren't using [FOLIO](https://folio.org/) as the backend

For feedback/reporting issues on the Dockerfile or the associated Run Script, please use our Github repo (https://github.com/TAMULib/metadb-docker/issues). Please note that we are not the developers of MetaDB, so any issues for the underlying software should be submitted to the developer's github repo (https://github.com/metadb-project/metadb/issues).

# Setup

There are two ways to setup this container-- with an existing and valid metadb.conf file mounted to the container, or with all of the BACKEND_ environment variables set. Note that the existence of a metadb.conf file at DATA_DIR will completely disable the use of the BACKEND_ environment variables.

To mount an existing metadb.conf file, first create a Secret in Kubernetes with a single entry. The entry's key must be "metadb.conf", and the value must be the contents of the file. Then, reconfigure the workload to mount this Secret to wherever you have DATA_DIR set (default: /etc/metadb). Make sure UID 1000 has permission to read this mounted file. To mount other files in the DATA_DIR directory, simply append more entries to this Secret and set the key of the entry to what you want the file to be named.

The variables 

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
|BACKEND_PG_SUPERUSER         |       postgres                                 |                                                                |Optional.                                                          |
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

# Derived Tables

There are two main ways to run Derived Tables jobs against your analytics (BACKEND_) database-- the build-in method and a CronJob. 

The built-in method involves cloning the PUBLIC (private is unsupported) git repo specified with DERIVED_TABLES_GIT_REPO, from the tag or branch specified with DERIVED_TABLES_GIT_REFS. To specify a tag, set DERIVED_TABLES_GIT_REFS to "refs/tags/TAG_NAME_HERE" (replacing TAG_NAME_HERE with the tag name). To specify a branch, set DERIVED_TABLES_GIT_REFS to "refs/heads/BRANCH_NAME_HERE" (replacing BRANCH_NAME_HERE with the name of the branch). The cloned repository MUST contain a folder named "sql_metadb", and inside of that folder there MUST be another folder named "derived_tables", and inside of that folder there MUST be a text file named "runlist.txt". The job works by reading in the "runlist.txt" file one line at-a-time, and running each line in order as a SQL script file against the configured analytics database.

The CronJob method is exactly as it sounds, it is some kind of recurring scheduled task which uses 'psql' and/or third-party postgres clients to read and write to the analytics database. This is not officially supported by this image, but it would certainly work.

# Links

DockerHub: https://hub.docker.com/repository/docker/tamulibraries/metadb

MetaDB Github: https://github.com/metadb-project/metadb

MetaDB Documentation: https://metadb.dev/doc/1.3/
