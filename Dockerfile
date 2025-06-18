# Build Image Layer
FROM debian:trixie-slim AS build

# Install Dependencies
WORKDIR /root
RUN apt update -y
RUN apt install gcc golang ragel ca-certificates git -y
RUN update-ca-certificates
RUN go install golang.org/x/tools/cmd/goyacc@master
RUN cp /root/go/bin/goyacc /usr/bin

# Start Build
RUN git clone https://github.com/metadb-project/metadb.git -b v1.4.0-rc1
WORKDIR /root/metadb
COPY ./modify-code.sh .
RUN chmod o+rx ./modify-code.sh
RUN ./modify-code.sh
RUN chmod o+rx ./build
RUN ./build

# Host Image Layer
FROM debian:trixie-slim AS host

RUN apt update -y
RUN apt upgrade -y
RUN apt install sudo postgresql-client ca-certificates -y
RUN update-ca-certificates

# Copy Scripts and Binaries
COPY --from=build /root/metadb/bin/metadb /usr/bin/metadb
COPY --from=build /root/go/bin/goyacc /usr/bin/goyacc
COPY ./run-metadb.sh /opt/run-metadb.sh
RUN chmod ugo+rx /opt/run-metadb.sh
RUN chmod ugo+rx /usr/bin/metadb
RUN chmod ugo+rx /usr/bin/goyacc

# Default Port
EXPOSE 8550

# Environment Variables
ENV DATA_PATH="/data/metadb"
ENV LOG_FILE_PATH="/data/metadb/metadb.log"
ENV VERBOSE_LOGGING="false"
ENV MEM_LIMIT_GB="2"
ENV METADB_PORT="8550"
ENV BACKEND_DB_HOST="pg-metadb"
ENV BACKEND_DB_PORT="5432"
ENV BACKEND_PG_DATABASE="metadb"
ENV BACKEND_PG_SUPERUSER="postgres"
ENV BACKEND_PG_SUPERUSER_PASSWORD=""
ENV BACKEND_PG_USER="metadb"
ENV BACKEND_PG_USER_PASSWORD=""
ENV BACKEND_PG_SSLMODE="prefer"
ENV METADB_RUN_MODE="start | upgrade | sync | endsync | migrate"
ENV KAFKA_BROKERS="kafka:9092"
ENV KAFKA_TOPICS="^metadb_sensor_1\."
ENV KAFKA_CONSUMER_GROUP="metadb_sensor_1_1"
ENV SCHEMA_STOP_FILTER="admin"
ENV KAFKA_SECURITY="plaintext | ssl"
ENV ADD_SCHEMA_PREFIX="folio_"
ENV FOLIO_TENANT_NAME="tamu"
ENV LDP_CONF_FILE_PATH="/ldpconf/ldpconf.json"
ENV DERIVED_TABLES_GIT_REPO="https://github.com/folio-org/folio-analytics.git"
ENV DERIVED_TABLES_GIT_TAG="refs/tags/v1.8.0"
ENV FORCE_RUN="false"

# Specify Non-root User
RUN useradd metadb
WORKDIR /opt

ENTRYPOINT ["/opt/run-metadb.sh"]
