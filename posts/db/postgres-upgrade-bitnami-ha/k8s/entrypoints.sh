#!/usr/bin/env bash

set -o errtrace
set -o errexit
set -o nounset
set -o pipefail
set -o xtrace

if grep -q 14 "${PGDATAOLD}/PG_VERSION"; then
  echo "PGDATA is 14, do upgrade..."

  rm -rf /bitnami/postgresql/datanew

  mkdir -p /opt/bitnami/postgresql/logs/
  mkdir -p /bitnami/postgresql/data/conf.d
  chown -R 999:999 /opt/bitnami/postgresql/
  chown -R 999:999 /opt/bitnami/postgresql/logs/
  docker-upgrade pg_upgrade --socketdir=/tmp --check
  docker-upgrade pg_upgrade --socketdir=/tmp --link # --link: use hard links instead of copying files to the new cluster
  rm -rf /bitnami/postgresql/data/postgresql.conf /bitnami/postgresql/data/pg_hba.conf
  mv ${PGDATAOLD} ${PGDATAOLD}-$(date "+%Y%m%d%H%M%S")
  mv ${PGDATANEW} ${PGDATAOLD}
  chown -R 1001:0 ${PGDATABASE}
  chown -R 1001:0 ${PGDATABASE}/data/
  echo "PGDATA is 14, do upgrade finished"
  exit 0
fi

echo "do nothing"
