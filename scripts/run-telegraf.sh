#!/usr/bin/env bash
# Start the Telegraf agent container (telegraf-agent) managed by Telegraf Controller.
# UNTESTED scaffold. Reads ./.env from the current directory.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ ! -f ./.env ]; then
  echo "Missing ./.env (copy .env.example and fill it in, chmod 600)." >&2
  exit 1
fi

set -a
# shellcheck disable=SC1091
. ./.env
set +a

for v in CONFIG_ID AGENT_ID INFLUX_TOKEN TELEGRAF_CONTROLLER_TOKEN \
         INFLUX_URL INFLUX_ORG INFLUX_BUCKET AGENT_HOSTNAME; do
  if [ -z "${!v:-}" ]; then
    echo "Refusing to start: ${v} is empty in ./.env" >&2
    exit 1
  fi
done

if [ ! -S /var/run/docker.sock ]; then
  echo "Docker socket not found at /var/run/docker.sock" >&2
  exit 1
fi

DOCKER_GID="${DOCKER_GID:-$(stat -c %g /var/run/docker.sock)}"
export WATCH_CONTAINERS="${WATCH_CONTAINERS:-*}"

# WARNING: the docker socket gives root-equivalent access to the host.
# The :ro flag does NOT restrict the Docker API.
docker run -d \
  --name telegraf-agent \
  --restart unless-stopped \
  --network host \
  --memory 512m \
  --group-add "${DOCKER_GID}" \
  -e TELEGRAF_CONTROLLER_TOKEN \
  -e INFLUX_TOKEN \
  -e INFLUX_URL -e INFLUX_ORG -e INFLUX_BUCKET -e AGENT_HOSTNAME -e WATCH_CONTAINERS \
  -e HOST_MOUNT_PREFIX=/hostfs \
  -e HOST_ETC=/hostfs/etc \
  -e HOST_PROC=/hostfs/proc \
  -e HOST_SYS=/hostfs/sys \
  -v /:/hostfs:ro \
  -v /var/run/docker.sock:/var/run/docker.sock:ro \
  -v "${SCRIPT_DIR}/psi-lineprotocol.sh:/etc/telegraf/psi-lineprotocol.sh:ro" \
  telegraf:1.40.2 \
  --config "http://127.0.0.1:8888/api/configs/${CONFIG_ID}/toml?agent_id=${AGENT_ID}" \
  --config-url-watch-interval 1m

echo "telegraf-agent started. Check with: docker logs --tail 50 telegraf-agent"
