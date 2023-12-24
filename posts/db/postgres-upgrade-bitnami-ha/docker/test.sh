#!/usr/bin/env bash

set -o errtrace
set -o errexit
set -o nounset
set -o pipefail
set -o xtrace

cd "$(dirname "$0")"

export database='postgres://postgres:test@localhost:5432/test?sslmode=disable'

docker-compose down
rm -rf data
sleep 3

docker-compose up -d db14
sleep 5
docker-compose exec db14 pg_isready -d "$database" -t 20

docker-compose exec db14 psql "$database" -c 'select version();'
docker-compose exec db14 psql "$database" -c 'CREATE TABLE IF NOT EXISTS t_test( ID INT NOT NULL, NAME      TEXT  NOT NULL, AGE      INT   NOT NULL, ADDRESS    CHAR(50), SALARY     REAL );'
docker-compose exec db14 psql "$database" -c 'select count(*) from t_test;'
docker-compose exec db14 psql "$database" -c 'insert into t_test SELECT generate_series(1,1) as key,repeat( chr(int4(random()*26)+65),4), (random()*(6^2))::integer,null,(random()*(10^4))::integer;'
docker-compose exec db14 psql "$database" -c 'select count(*) from t_test;'

docker-compose stop db14

docker-compose up -d upgrade

docker-compose exec upgrade docker-upgrade pg_upgrade

docker-compose up -d db15
sleep 3
docker-compose exec db15 psql "$database" -c 'ALTER DATABASE test REFRESH COLLATION VERSION;'
docker-compose exec db15 vacuumdb --username=postgres --all --analyze-in-stages

# docker-compose exec db15 psql "$database" -c 'REINDEX DATABASE test;'
# docker-compose exec db15 psql "$database" -c 'ALTER DATABASE test REFRESH COLLATION VERSION;'

docker-compose logs -f db15
