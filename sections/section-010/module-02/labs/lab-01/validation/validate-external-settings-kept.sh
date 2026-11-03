#!/usr/bin/env bash
# PASS when the release still uses the external services, the Secrets and the certificate Secret, and holds no password
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

values="$(helm -n harbor get values harbor -o json 2>/dev/null)"
if [ -z "$values" ]; then
  echo "FAIL: helm cannot read the values of the release harbor."
  exit 1
fi
check() {
  # check LABEL JQ_FILTER EXPECTED
  local actual
  actual="$(printf '%s' "$values" | ws jq -r "$2")"
  if [ "$actual" != "$3" ]; then
    echo "FAIL: $1 is '$actual', expected '$3'."
    exit 1
  fi
}
check "database.type" '.database.type' external
check "database.external.existingSecret" '.database.external.existingSecret' harbor-external-db
check "redis.type" '.redis.type' external
check "persistence.imageChartStorage.type" '.persistence.imageChartStorage.type' s3
check "persistence.imageChartStorage.s3.existingSecret" '.persistence.imageChartStorage.s3.existingSecret' harbor-s3
check "expose.tls.secret.secretName" '.expose.tls.secret.secretName' harbor-tls
check "externalURL" '.externalURL' https://harbor.localtest.me:8443
check "existingSecretSecretKey" '.existingSecretSecretKey' harbor-secretkey
if printf '%s' "$values" | grep -q 'harbor-db-password\|harbor-s3-secret'; then
  echo "FAIL: a password or key from the lab Secrets appears in the Helm values."
  exit 1
fi
echo "PASS: the release keeps the external services, the Secrets, the certificate and the external URL, and holds no password."
