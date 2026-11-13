#!/usr/bin/env bash
# Preflight for Ubuntu hosts: checks must-fix #6 prerequisites before anything starts.
# Read-only. Exit 1 if any hard check fails. PROPOSED new file scripts/preflight.sh.
set -u
fail=0
ok()   { printf '[ ok ] %s\n' "$*"; }
warn() { printf '[warn] %s\n' "$*"; }
bad()  { printf '[FAIL] %s\n' "$*"; fail=1; }

. /etc/os-release 2>/dev/null && ok "OS: ${PRETTY_NAME:-unknown} ($(uname -m))"
case "$(uname -m)" in x86_64|aarch64) ;; *) bad "Unsupported CPU $(uname -m); images are amd64/arm64 only." ;; esac

command -v docker >/dev/null || { bad "docker not found (install Docker Engine from docs.docker.com, not the snap)."; exit 1; }

# Snap Docker cannot bind-mount / or see the real /var/run/docker.sock the same way.
if readlink -f "$(command -v docker)" | grep -q '^/snap/'; then
  bad "Docker is the snap package: unsupported (confinement breaks the / mount)."
fi

docker info >/dev/null 2>&1 || { bad "Cannot talk to the Docker daemon (not running, or you are not in the 'docker' group)."; exit 1; }
ok "Docker daemon reachable"

if docker info --format '{{.SecurityOptions}}' 2>/dev/null | grep -q rootless; then
  bad "Rootless Docker detected: unsupported (needs a root daemon for the host mounts and PSI)."
else
  ok "Root daemon (not rootless)"
fi

[ -S /var/run/docker.sock ] && ok "docker.sock GID = $(stat -c %g /var/run/docker.sock)" || bad "No /var/run/docker.sock"
id -nG | tr ' ' '\n' | grep -qx docker && ok "User is in the docker group" \
  || warn "User not in docker group (needed unless you run with sudo; membership = root-equivalent)."

[ -r /proc/pressure/memory ] && ok "PSI available" || warn "No /proc/pressure: PSI metrics will be empty (kernel < 4.20 or psi=0)."
docker compose version >/dev/null 2>&1 && ok "docker compose plugin present" || warn "No compose plugin: use the scripts/ path."
command -v openssl >/dev/null && ok "openssl present" || warn "openssl missing (make-env.sh / run-controller.sh need it)."

for p in 8888 8000; do
  if ss -ltn 2>/dev/null | awk '{print $4}' | grep -q "[:.]${p}\$"; then warn "Port ${p} already in use"; else ok "Port ${p} free"; fi
done

[ "${fail}" -eq 0 ] && echo "Preflight passed." || echo "Preflight FAILED."
exit "${fail}"
