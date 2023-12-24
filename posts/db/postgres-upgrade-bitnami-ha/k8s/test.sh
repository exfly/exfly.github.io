mkdir -p tmp
bash kind-with-registry.sh

docker build -t tianon/postgres-upgrade:14-to-15 -f pg_upgrade/Dockerfile pg_upgrade
kind load docker-image tianon/postgres-upgrade:14-to-15

export KUBECONFIG=$PWD/tmp/kubeconf.yaml
(cd tmp && helm pull oci://registry-1.docker.io/bitnamicharts/postgresql-ha --version 12.3.1)
helm upgrade --install shared tmp/postgresql-ha-12.3.1.tgz -f shared.yaml --set postgresql.image.tag='14.10.0-debian-11-r6'

kubectl rollout status sts shared-postgresql-ha-postgresql -w
bash cluster_upgrade.sh
