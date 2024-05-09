#!/usr/bin/env bash

set -o errtrace
set -o errexit
set -o nounset
set -o pipefail
set -o xtrace

cd "$(dirname "$0")"

function debug() {
  echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')]:DEBU: $*" >&2
}

function info() {
  echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')]:INFO: $*" >&2
}

function err() {
  echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')]:ERRR: $*" >&2
}

DOCKER_VERSION="${DOCKER_VERSION:-"26.1.1"}"
DOCKRE_MIRROR=${DOCKRE_MIRROR:-"https://mirrors.tuna.tsinghua.edu.cn"}

function machine_arch() {
    arch=$(uname -m)
    case $arch in
        x86_64)
            echo amd64
            ;;
        aarch64)
            echo arm64
            ;;
        *)
            echo $arch
            ;;
    esac
}

function docker_arch() {
	arch=$(uname -m)
    case $arch in
        arm64)
            echo aarch64
            ;;
        *)
            echo $arch
            ;;
    esac
}

# https://mirrors.tuna.tsinghua.edu.cn/docker-ce/linux/static/stable/aarch64/docker-26.1.1.tgz
DOCKER_DOWNLOAD_URL="${DOCKRE_MIRROR}/docker-ce/linux/static/stable/$(docker_arch)/docker-${DOCKER_VERSION}.tgz"

BASEPATH=./installer
mkdir -p $BASEPATH

pushd $BASEPATH
wget $DOCKER_DOWNLOAD_URL
popd

mkdir -p $BASEPATH/docker
cat > $BASEPATH/docker/daemon.json <<'EOF'
{
  "live-restore": true,
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "200m"
  }
}
EOF

mkdir -p $BASEPATH/systemd
cat > $BASEPATH/systemd/containerd.service <<'EOF'
[Unit]
Description=containerd container runtime
Documentation=https://containerd.io
After=network.target

[Service]
ExecStartPre=-/sbin/modprobe overlay
ExecStart=/usr/local/bin/containerd

Restart=always
RestartSec=2
TimeoutSec=30
StartLimitInterval=0

KillMode=process
Delegate=yes
LimitNOFILE=1048576
# Having non-zero Limit*s causes performance problems due to accounting overhead
# in the kernel. We recommend using cgroups to do container-local accounting.
LimitNPROC=infinity
LimitCORE=infinity
# TasksMax=infinity

[Install]
WantedBy=multi-user.target
EOF

cat > $BASEPATH/systemd/docker.service <<'EOF'
[Unit]
Description=Docker Application Container Engine
Documentation=https://docs.docker.com
BindsTo=containerd.service
After=network-online.target firewalld.service
Wants=network-online.target
Requires=docker.socket

[Service]
Type=notify
# the default is not to use systemd for cgroups because the delegate issues still
# exists and systemd currently does not support the cgroup feature set required
# for containers run by docker
ExecStart=/usr/local/bin/dockerd -H fd://
ExecReload=/bin/kill -s HUP $MAINPID
TimeoutSec=30
RestartSec=2
Restart=always

# Note that StartLimit* options were moved from "Service" to "Unit" in systemd 229.
# Both the old, and new location are accepted by systemd 229 and up, so using the old location
# to make them work for either version of systemd.
StartLimitBurst=3

# Note that StartLimitInterval was renamed to StartLimitIntervalSec in systemd 230.
# Both the old, and new name are accepted by systemd 230 and up, so using the old name to make
# this option work for either version of systemd.
# retry start always
StartLimitInterval=0

# Having non-zero Limit*s causes performance problems due to accounting overhead
# in the kernel. We recommend using cgroups to do container-local accounting.
LimitNOFILE=infinity
LimitNPROC=infinity
LimitCORE=infinity

# Comment TasksMax if your systemd version does not supports it.
# Only systemd 226 and above support this option.
# TasksMax=infinity

# set delegate yes so that systemd does not reset the cgroups of docker containers
Delegate=yes

# kill only the docker process, not all processes in the cgroup
KillMode=process

[Install]
WantedBy=multi-user.target
EOF

cat > $BASEPATH/systemd/docker.socket <<'EOF'
[Unit]
Description=Docker Socket for the API
PartOf=docker.service

[Socket]
ListenStream=/var/run/docker.sock
SocketMode=0660
SocketUser=root
SocketGroup=docker

[Install]
WantedBy=sockets.target
EOF

tar -zvcf dockerbin-installer.tar.gz installer install.sh
