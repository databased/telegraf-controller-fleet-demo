#!/usr/bin/env bash
# Quick health snapshot of the Controller and agent containers.
set -u

echo "== Controller readiness =="
curl -sS -m 5 -o /dev/null -w "HTTP %{http_code}\n" http://127.0.0.1:8888/health/ready || echo "controller not reachable"

echo
echo "== Containers =="
docker ps --filter name=telegraf-controller --filter name=telegraf-agent \
  --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}'

echo
echo "== Resource use =="
running="$(docker ps --format '{{.Names}}' | grep -E '^(telegraf-controller|telegraf-agent)$' || true)"
if [ -n "${running}" ]; then
  # shellcheck disable=SC2086
  docker stats --no-stream ${running}
else
  echo "no matching containers running"
fi

echo
echo "== Disk =="
df -h /
