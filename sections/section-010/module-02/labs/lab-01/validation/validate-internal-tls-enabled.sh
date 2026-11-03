#!/usr/bin/env bash
# PASS when internal TLS is on: the components listen on 8443 and the chart created the per-component Secrets
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

for component in core jobservice registry portal; do
  if ! kubectl -n harbor get secret "harbor-$component-internal-tls" >/dev/null 2>&1; then
    echo "FAIL: the Secret harbor-$component-internal-tls does not exist; internal TLS is not enabled."
    exit 1
  fi
done
port="$(kubectl -n harbor get configmap harbor-core -o jsonpath='{.data.PORT}' 2>/dev/null)"
if [ "$port" != "8443" ]; then
  echo "FAIL: core listens on port '${port:-unknown}', not 8443."
  exit 1
fi
for component in core jobservice registry portal; do
  ready="$(kubectl -n harbor get deployment "harbor-$component" -o jsonpath='{.status.readyReplicas}' 2>/dev/null)"
  if [ "${ready:-0}" -lt 1 ]; then
    echo "FAIL: deployment harbor-$component has no ready replica."
    exit 1
  fi
done
echo "PASS: internal TLS is on: core listens on 8443 and every component has its internal certificate Secret."
