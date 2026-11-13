#!/usr/bin/env bash
# Start Telegraf Controller in Docker, bound to loopback only.
# UNTESTED scaffold. You must accept the EULA yourself by setting ACCEPT_EULA=accept
# (the same spelling compose.yaml and the product use).
set -euo pipefail

EULA_URL="https://docs.influxdata.com/telegraf/controller/reference/eula/"

if [ "${ACCEPT_EULA:-}" != "accept" ]; then
  echo "Refusing to start: the Telegraf Controller EULA has not been accepted." >&2
  echo "Read it at: ${EULA_URL}" >&2
  echo "If you accept it, re-run with: ACCEPT_EULA=accept $0" >&2
  exit 1
fi

SECRET_DIR="${HOME}/.config/telegraf-controller-demo"
SECRET_FILE="${SECRET_DIR}/session_secret"

if [ ! -s "${SECRET_FILE}" ]; then
  mkdir -p "${SECRET_DIR}"
  chmod 700 "${SECRET_DIR}"
  umask 077
  openssl rand -base64 48 > "${SECRET_FILE}"
  chmod 600 "${SECRET_FILE}"
  echo "Created ${SECRET_FILE} (mode 600)."
fi

SESSION_SECRET="$(cat "${SECRET_FILE}")"

# Note: no OWNER_* variables. The owner account is created in the browser.
docker run -d \
  --name telegraf-controller \
  --restart unless-stopped \
  --memory 512m \
  --cpus 0.5 \
  -p 127.0.0.1:8888:8888 \
  -p 127.0.0.1:8000:8000 \
  -v telegraf-controller:/var/lib/telegraf-controller \
  -e TELEGRAF_CONTROLLER_EULA="${ACCEPT_EULA}" \
  -e SESSION_SECRET="${SESSION_SECRET}" \
  influxdata/telegraf-controller:1.2.0

echo "Controller started. Tunnel with: ssh -N -L 8888:127.0.0.1:8888 <host>"
echo "Then browse to http://localhost:8888"
