#!/usr/bin/env bash

set -o errtrace
set -o errexit
set -o nounset
set -o pipefail
set -o xtrace

cd "$(dirname "$0")"

export STS_NAME=shared

kubectl exec -i $STS_NAME-postgresql-ha-postgresql-0 -- cat /bitnami/postgresql/data/PG_VERSION > TMP_PG_VERSION.txt

if grep -q 14 "TMP_PG_VERSION.txt"; then
	echo "PGDATA is 14, do upgrade..."

	# STEP: 降低副本数，让 node1 为主节点
	kubectl scale --replicas=1 sts $STS_NAME-postgresql-ha-postgresql
	until [ $(kubectl get pod -l app=postgres-ha,app.kubernetes.io/instance=$STS_NAME,role=data -o name | wc -l) = "1" ];
	do
		echo "waiting sharedx scale to 1..."
		sleep 10s
	done
	echo "sharedx pod count is $(kubectl get pod -l app=postgres-ha,app.kubernetes.io/instance=$STS_NAME,role=data -o name | wc -l)"
	kubectl rollout status     sts $STS_NAME-postgresql-ha-postgresql -w # 全 terminal 后，就会通过，非预期，

	## STEP: 准备主数据目录的 pg 配置文件
	kubectl exec -i $STS_NAME-postgresql-ha-postgresql-0 -- bash -x - <<'EOF'
cat /opt/bitnami/postgresql/conf/postgresql.conf | grep shared_preload_libraries
EOF
	kubectl exec -i $STS_NAME-postgresql-ha-postgresql-0 -- bash -x - <<'EOF'
cat /opt/bitnami/postgresql/conf/postgresql.conf > /bitnami/postgresql/data/postgresql.conf
cat /opt/bitnami/postgresql/conf/conf.d/extra_conf.conf >> /bitnami/postgresql/data/postgresql.conf
cat /opt/bitnami/postgresql/conf/pg_hba.conf > /bitnami/postgresql/data/pg_hba.conf
sed -i 's/repmgr, pgaudit, repmgr, //' /bitnami/postgresql/data/postgresql.conf
sed -i 's/local    all              all                    md5/local    all              all                    trust/' /bitnami/postgresql/data/pg_hba.conf
EOF
	# shared_preload_libraries

	kubectl scale --replicas=0 sts $STS_NAME-postgresql-ha-postgresql
	kubectl rollout status     sts $STS_NAME-postgresql-ha-postgresql -w

	# STEP: 创建 pg_upgrade 容器升级
	kubectl delete job/pgupgrade || true
	kubectl kustomize . | kubectl apply -f -
	kubectl logs -l app=pgupgrade || true
	kubectl wait --for=condition=complete --timeout=86400s job/pgupgrade # 86400s 1天
	# kubectl exec -it $(kubectl get pod -l app=pgupgrade -o name | tail -n 1) -- bash
	echo "PGDATA is 14, do upgrade finished"
	# STEP: 升级新的集群
	helm upgrade --install $STS_NAME tmp/postgresql-ha-12.3.1.tgz -f shared.yaml --set postgresql.image.tag='15.5.0-debian-11-r10'

	# STEP: 升级后数据维护
	kubectl rollout status     sts $STS_NAME-postgresql-ha-postgresql -w
	kubectl exec -i $STS_NAME-postgresql-ha-postgresql-0 -- bash -x - <<'EOF'
export PGPASSWORD=$POSTGRES_PASSWORD; vacuumdb --username=postgres --no-password --all --analyze-in-stages
EOF

	exit 0
fi

echo 'PGDATA not 14, do nothing'
