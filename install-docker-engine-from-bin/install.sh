#!/usr/bin/env bash

set -o errtrace
set -o errexit
set -o nounset
set -o pipefail
set -o xtrace

cd "$(dirname "$0")"

BASEPATH=./installer
DOCKER_BIN_DIR=/usr/local/bin

function is_cmd_exists() {
	command -v "$1" >/dev/null 2>&1
}

function debug() {
	echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')]:DEBU: $*" >&2
}

function info() {
	echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')]:INFO: $*" >&2
}

function err() {
	echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')]:ERRR: $*" >&2
}

user="$(id -un 2>/dev/null || true)"
sh_c='sh -c'
if [ "$user" != 'root' ]; then
	cat >&2 <<-'EOF'
		Error: this installer needs the ability to run commands as root.
		You can exec `sudo su`, and reinstall.
	EOF
	exit 1
fi

stat /run/systemd || (echo "not systemd"; exit 1)
docker version && exit 0

mkdir -p $DOCKER_BIN_DIR
tar xvf $BASEPATH/docker-*.tgz --strip-components 1 -C $DOCKER_BIN_DIR

mkdir -p /etc/docker
cp $BASEPATH/docker/* /etc/docker/

cp $BASEPATH/systemd/* /etc/systemd/system

sync
groupadd -f docker || true
systemctl daemon-reload
systemctl enable docker
systemctl restart docker
