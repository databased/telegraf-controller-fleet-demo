#!/usr/bin/env bash
# Scan a tree for things that should not be committed.
# Usage: redaction-check.sh [DIR]   (default: current directory)
# Exit 1 if any match is found, 0 if clean. This script excludes itself.
set -u

DIR="${1:-.}"
found=0

check() {
  label="$1"
  pattern="$2"
  out="$(grep -RInE --exclude-dir=.git --exclude='redaction-check.sh' -e "$pattern" "$DIR" 2>/dev/null || true)"
  if [ -n "$out" ]; then
    echo "[MATCH] ${label}"
    echo "$out"
    found=1
  fi
}

check "token-like base64 (40+ chars ending in =)" '[A-Za-z0-9+/_-]{40,}={1,2}'
check "token-like hex (40+ chars)" '(^|[^0-9A-Fa-f])[0-9A-Fa-f]{40,}($|[^0-9A-Fa-f])'
check "Authorization header" 'Authorization'
check "private IPv4 address" '(^|[^0-9.])(10\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}|192\.168\.[0-9]{1,3}\.[0-9]{1,3}|172\.(1[6-9]|2[0-9]|3[01])\.[0-9]{1,3}\.[0-9]{1,3})([^0-9]|$)'
check "ssh public key" 'ssh-rsa'
check "private key block" 'BEGIN .* PRIVATE KEY'
check "password with value" 'password=[^[:space:]]+'

if [ "$found" -eq 1 ]; then
  echo "Redaction check FAILED."
  exit 1
fi
echo "Redaction check clean."
exit 0
