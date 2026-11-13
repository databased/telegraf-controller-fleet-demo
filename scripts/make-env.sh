#!/usr/bin/env bash
# Create ./.env (mode 600). Prompts for secrets with hidden input, GENERATES
# SESSION_SECRET, DETECTS DOCKER_GID, and asks for the previously hard-coded
# org / bucket / URL / host names. PROPOSED replacement for scripts/make-env.sh.
set -euo pipefail

ENV_FILE="${1:-./.env}"

if [ ! -t 0 ]; then
  echo "This script needs a terminal for hidden input (use ssh -t)." >&2
  exit 1
fi

if [ -e "${ENV_FILE}" ]; then
  printf '%s already exists. Overwrite? Type yes to continue: ' "${ENV_FILE}"
  read -r answer
  [ "${answer}" = "yes" ] || { echo "Left ${ENV_FILE} unchanged."; exit 1; }
fi

reject_bad() {  # single quotes would break the quoted .env; spaces break plain values
  case "$1" in *"'"*) echo "Value contains a single quote. Aborting." >&2; exit 1 ;; esac
}

ask_secret() {
  local prompt="$1" value=""
  printf '%s: ' "${prompt}" >&2
  IFS= read -r -s value
  printf '\n' >&2
  [ -n "${value}" ] || { echo "Empty value, aborting." >&2; exit 1; }
  reject_bad "${value}"
  printf '%s' "${value}"
}

ask_plain() {
  local prompt="$1" default="$2" value=""
  printf '%s [%s]: ' "${prompt}" "${default}" >&2
  IFS= read -r value
  value="${value:-${default}}"
  [ -n "${value}" ] || { echo "Value required, aborting." >&2; exit 1; }
  case "${value}" in *" "*) echo "Value must not contain spaces. Aborting." >&2; exit 1 ;; esac
  reject_bad "${value}"
  printf '%s' "${value}"
}

# --- items that were missing (must-fix #1) ---
command -v openssl >/dev/null || { echo "openssl is required to generate SESSION_SECRET." >&2; exit 1; }
SESSION_SECRET="$(openssl rand -base64 48 | tr -d '\n')"

if [ -S /var/run/docker.sock ]; then
  DOCKER_GID="$(stat -c %g /var/run/docker.sock)"
else
  echo "No /var/run/docker.sock: is Docker installed and running? Aborting." >&2
  exit 1
fi

# --- secrets ---
INFLUX_TOKEN="$(ask_secret 'InfluxDB Cloud WRITE-only token')"
TELEGRAF_CONTROLLER_TOKEN="$(ask_secret 'Controller API token (Telegraf Agent preset)')"

# --- previously hard-coded (must-fix #4): no defaults tied to the author's account ---
INFLUX_URL="$(ask_plain 'InfluxDB Cloud URL' 'https://REGION.aws.cloud2.influxdata.com')"
INFLUX_ORG="$(ask_plain 'InfluxDB org' '')"
INFLUX_BUCKET="$(ask_plain 'InfluxDB bucket' '')"
CONFIG_ID="$(ask_plain 'Controller config ID' '')"
AGENT_ID="$(ask_plain 'Agent ID (as shown in Controller)' "$(hostname -s)")"
AGENT_HOSTNAME="$(ask_plain 'Host name tag for metrics' "$(hostname -s)")"
WATCH_CONTAINERS="$(ask_plain 'Container name glob to watch (docker input)' '*')"

umask 077
{
  printf "ACCEPT_EULA=''\n"   # left empty on purpose: the human sets it after reading the EULA
  printf "SESSION_SECRET='%s'\n" "${SESSION_SECRET}"
  printf "DOCKER_GID='%s'\n" "${DOCKER_GID}"
  printf "INFLUX_TOKEN='%s'\n" "${INFLUX_TOKEN}"
  printf "TELEGRAF_CONTROLLER_TOKEN='%s'\n" "${TELEGRAF_CONTROLLER_TOKEN}"
  printf "INFLUX_URL='%s'\n" "${INFLUX_URL}"
  printf "INFLUX_ORG='%s'\n" "${INFLUX_ORG}"
  printf "INFLUX_BUCKET='%s'\n" "${INFLUX_BUCKET}"
  printf "CONFIG_ID='%s'\n" "${CONFIG_ID}"
  printf "AGENT_ID='%s'\n" "${AGENT_ID}"
  printf "AGENT_HOSTNAME='%s'\n" "${AGENT_HOSTNAME}"
  printf "WATCH_CONTAINERS='%s'\n" "${WATCH_CONTAINERS}"
} > "${ENV_FILE}"
chmod 600 "${ENV_FILE}"

echo "Wrote ${ENV_FILE} (mode 600). Variable names only:"
cut -d= -f1 "${ENV_FILE}"
echo "Next: read the EULA, then set ACCEPT_EULA=accept yourself (in the shell or in ${ENV_FILE})."
