#!/usr/bin/env bash
# PASS when the running core pod holds the new password, Harbor is healthy and a push and pull work
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

NEW="rotated-db-password-2"
held="$(kubectl -n harbor exec deploy/harbor-core -- printenv POSTGRESQL_PASSWORD 2>/dev/null)"
if [ "$held" != "$NEW" ]; then
  echo "FAIL: the running core pod does not hold the new password; it was not restarted after the Secret changed."
  exit 1
fi
if ! wait_for_harbor; then
  echo "FAIL: /api/v2.0/health does not report every component healthy."
  harbor_api GET /health 2>/dev/null
  exit 1
fi
TAG="grader-$(date +%s)"
registry_login
if ! ws regctl image copy ghcr.io/stefanprodan/podinfo:6.15.0 "harbor.localtest.me:8443/inventory/podinfo:$TAG" >/dev/null 2>&1; then
  echo "FAIL: pushing inventory/podinfo:$TAG to Harbor failed."
  exit 1
fi
ws rm -rf /tmp/grader-pull
if ! ws regctl image copy "harbor.localtest.me:8443/inventory/podinfo:$TAG" "ocidir:///tmp/grader-pull:$TAG" >/dev/null 2>&1; then
  echo "FAIL: pulling inventory/podinfo:$TAG back from Harbor failed."
  exit 1
fi
echo "PASS: core runs with the new password, Harbor is healthy, and a push and pull work."
