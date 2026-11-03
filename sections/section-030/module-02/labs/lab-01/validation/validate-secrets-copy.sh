#!/usr/bin/env bash
# PASS when the Secret copy and the values backup match the live objects
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

for key in tls.crt tls.key ca.crt; do
  LIVE="$(kubectl -n harbor get secret harbor-tls -o json 2>/dev/null | ws jq -r --arg k "$key" '.data[$k] // empty')"
  COPY="$(kubectl -n harbor-deps get secret harbor-backup-copy -o json 2>/dev/null | ws jq -r --arg k "$key" '.data[$k] // empty')"
  if [ -z "$COPY" ] || [ "$LIVE" != "$COPY" ]; then
    echo "FAIL: the Secret harbor-backup-copy in harbor-deps has no key $key, or it differs from harbor-tls."
    exit 1
  fi
done
LIVE_KEY="$(kubectl -n harbor get secret harbor-secretkey -o jsonpath='{.data.secretKey}' 2>/dev/null)"
COPY_KEY="$(kubectl -n harbor-deps get secret harbor-backup-copy -o jsonpath='{.data.secretKey}' 2>/dev/null)"
if [ -z "$COPY_KEY" ] || [ "$LIVE_KEY" != "$COPY_KEY" ]; then
  echo "FAIL: the Secret harbor-backup-copy has no key secretKey, or it differs from harbor-secretkey."
  exit 1
fi
VALUES="$(kubectl -n harbor-deps get configmap harbor-values-backup -o jsonpath='{.data.values\.yaml}' 2>/dev/null)"
if ! echo "$VALUES" | grep -q 'externalURL: https://harbor.localtest.me:8443'; then
  echo "FAIL: the ConfigMap harbor-values-backup has no key values.yaml with the output of helm get values."
  exit 1
fi
echo "PASS: the Secret copy and the values backup match the live objects."
