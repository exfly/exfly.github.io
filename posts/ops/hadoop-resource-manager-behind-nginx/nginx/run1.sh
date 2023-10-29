#!/usr/bin/env bash

set -o errtrace
set -o errexit
set -o nounset
set -o pipefail
set -o xtrace

cd "$(dirname "$0")"

docker run --rm -it -p 38080:8080 -v $(pwd)/:/etc/nginx/conf.d/ nginx:latest nginx -c /etc/nginx/conf.d/nginx.conf_root
