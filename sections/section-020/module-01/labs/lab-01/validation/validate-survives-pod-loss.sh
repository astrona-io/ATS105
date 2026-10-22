#!/usr/bin/env bash
# PASS when pushes and pulls keep working while a core and a registry pod are replaced
set -uo pipefail

HELM_VERSION="3.22.1"
HARBOR_URL="https://harbor.localtest.me:8443"
for dir in /usr/local/bin "$HOME/.local/bin"; do
  [ -d "$dir" ] && PATH="$dir:$PATH"
done
export PATH

ws() {
  # ws COMMAND...: runs a command in the workstation pod.
  kubectl -n workstation exec -i deploy/workstation -- "$@"
}
harbor_api() {
  # harbor_api METHOD PATH [JSON]: calls the Harbor REST API v2.0 as admin.
  local method="$1" path="$2" body="${3:-}"
  if [ -n "$body" ]; then
    printf '%s' "$body" | ws curl -sS -u admin:Harbor12345 -X "$method" \
      -H 'Content-Type: application/json' --data-binary @- "$HARBOR_URL/api/v2.0$path"
  else
    ws curl -sS -u admin:Harbor12345 -X "$method" "$HARBOR_URL/api/v2.0$path"
  fi
}
harbor_status() {
  # harbor_status METHOD PATH [JSON]: prints only the HTTP status code.
  local method="$1" path="$2" body="${3:-}"
  if [ -n "$body" ]; then
    printf '%s' "$body" | ws curl -s -o /dev/null -w '%{http_code}' -u admin:Harbor12345 -X "$method" \
      -H 'Content-Type: application/json' --data-binary @- "$HARBOR_URL/api/v2.0$path"
  else
    ws curl -s -o /dev/null -w '%{http_code}' -u admin:Harbor12345 -X "$method" "$HARBOR_URL/api/v2.0$path"
  fi
}
psql_on() {
  # psql_on DEPLOYMENT SQL: runs one SQL statement against the registry database.
  kubectl -n harbor-deps exec -i "deploy/$1" -- psql -U harbor -d registry -tAc "$2"
}
s3() {
  # s3 ARGS...: runs `aws s3 ARGS` in the s3-client pod.
  kubectl -n harbor-deps exec -i deploy/s3-client -- aws s3 "$@"
}
registry_login() {
  ws regctl registry login harbor.localtest.me:8443 -u admin -p Harbor12345 >/dev/null 2>&1
}
wait_for_harbor() {
  # Waits until /api/v2.0/health reports every component healthy.
  for _ in $(seq 1 120); do
    if [ "$(harbor_api GET /health 2>/dev/null | ws jq -r '.status' 2>/dev/null)" = "healthy" ]; then
      return 0
    fi
    sleep 5
  done
  return 1
}

registry_login
core_pod="$(kubectl -n harbor get pods -l component=core -o name | head -1)"
registry_pod="$(kubectl -n harbor get pods -l component=registry -o name | head -1)"
if [ -z "$core_pod" ] || [ -z "$registry_pod" ]; then
  echo "FAIL: could not find a core and a registry pod (labels component=core, component=registry)."
  exit 1
fi
kubectl -n harbor delete "$core_pod" "$registry_pod" --wait=false >/dev/null
sleep 3
failures=0
for attempt in 1 2 3 4 5; do
  TAG="survive-$(date +%s)-$attempt"
  ws regctl image copy ghcr.io/stefanprodan/podinfo:6.15.0 "harbor.localtest.me:8443/inventory/podinfo:$TAG" >/dev/null 2>&1 || failures=$((failures + 1))
  ws regctl image copy "harbor.localtest.me:8443/inventory/podinfo:6.15.0" "ocidir:///tmp/survive:$attempt" >/dev/null 2>&1 || failures=$((failures + 1))
done
if [ "$failures" -gt 1 ]; then
  echo "FAIL: $failures of 10 pushes and pulls failed while a core and a registry pod were replaced."
  exit 1
fi
echo "PASS: pushes and pulls kept working while a core and a registry pod were replaced."
