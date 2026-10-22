#!/usr/bin/env bash
# PASS when Harbor's Helm values point at the right external services
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

VALUES="$(helm -n harbor get values harbor -o json 2>/dev/null)"
if [ -z "$VALUES" ]; then
  echo "FAIL: the Helm release harbor in the namespace harbor was not found."
  exit 1
fi
value() { printf '%s' "$VALUES" | ws jq -r "$1"; }
[ "$(value '.database.type')" = "external" ] || { echo "FAIL: database.type is not external."; exit 1; }
[ "$(value '.database.external.host')" = "postgres.harbor-deps.svc.cluster.local" ] || { echo "FAIL: database.external.host is not postgres.harbor-deps.svc.cluster.local."; exit 1; }
[ "$(value '.database.external.existingSecret')" = "harbor-database" ] || { echo "FAIL: database.external.existingSecret is not harbor-database."; exit 1; }
if [ "$(value '.database.external.password // empty')" != "" ]; then
  echo "FAIL: the database password is written in the Helm values. Read it from the Secret harbor-database instead."
  exit 1
fi
[ "$(value '.redis.type')" = "external" ] || { echo "FAIL: redis.type is not external."; exit 1; }
[ "$(value '.redis.external.addr')" = "redis.harbor-deps.svc.cluster.local:6379" ] || { echo "FAIL: redis.external.addr is not redis.harbor-deps.svc.cluster.local:6379."; exit 1; }
[ "$(value '.persistence.imageChartStorage.type')" = "s3" ] || { echo "FAIL: persistence.imageChartStorage.type is not s3."; exit 1; }
[ "$(value '.persistence.imageChartStorage.s3.bucket')" = "harbor" ] || { echo "FAIL: the S3 bucket is not harbor."; exit 1; }
[ "$(value '.persistence.imageChartStorage.s3.existingSecret')" = "harbor-s3" ] || { echo "FAIL: the S3 keys do not come from the Secret harbor-s3."; exit 1; }
if [ "$(value '.persistence.imageChartStorage.s3.secretkey // empty')" != "" ]; then
  echo "FAIL: the S3 secret key is written in the Helm values. Use the Secret harbor-s3."
  exit 1
fi
if ! value '.jobservice.jobLoggers // [] | join(",")' | grep -q database; then
  echo "FAIL: jobservice.jobLoggers does not include database."
  exit 1
fi
if kubectl -n harbor get statefulset harbor-database >/dev/null 2>&1 || kubectl -n harbor get statefulset harbor-redis >/dev/null 2>&1; then
  echo "FAIL: the internal database or Redis StatefulSet still runs in the namespace harbor."
  exit 1
fi
echo "PASS: Harbor uses the external PostgreSQL, Redis and S3 storage, with credentials from Secrets."
