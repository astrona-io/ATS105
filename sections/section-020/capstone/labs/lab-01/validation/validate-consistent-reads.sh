#!/usr/bin/env bash
# PASS when every read of a freshly pushed artifact succeeds
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

TAG="grader-$(date +%s)"
# push_fresh: pushes a small artifact with content Harbor has never seen.
# A copy of podinfo would reuse layers Harbor already knows from before the
# fix (core answers blob checks from its database), so nothing new would be
# uploaded and the test would not touch the new storage.
push_fresh() {
  printf 'grader %s %s\n' "$TAG" "$(date +%s)-$RANDOM" | ws regctl artifact put \
    --artifact-type application/vnd.astrona.grader.v1 "harbor.localtest.me:8443/inventory/podinfo:$TAG" >/dev/null 2>&1
}
registry_login
if ! push_fresh; then
  harbor_api POST /projects '{"project_name":"inventory","metadata":{"public":"false"}}' >/dev/null 2>&1
  if ! push_fresh; then
    echo "FAIL: pushing inventory/podinfo:$TAG to Harbor failed."
    exit 1
  fi
fi
ws rm -rf /tmp/grader-pull
if ! ws regctl image copy "harbor.localtest.me:8443/inventory/podinfo:$TAG" "ocidir:///tmp/grader-pull:$TAG" >/dev/null 2>&1; then
  echo "FAIL: pulling inventory/podinfo:$TAG back from Harbor failed."
  exit 1
fi
failures=0
for attempt in $(seq 1 20); do
  ws regctl manifest head "harbor.localtest.me:8443/inventory/podinfo:$TAG" >/dev/null 2>&1 || failures=$((failures + 1))
  ws regctl image copy "harbor.localtest.me:8443/inventory/podinfo:$TAG" "ocidir:///tmp/consistent:$attempt" >/dev/null 2>&1 || failures=$((failures + 1))
done
if [ "$failures" -gt 0 ]; then
  echo "FAIL: $failures of 40 reads of a freshly pushed artifact failed. The registry replicas do not share storage."
  exit 1
fi
if ! s3 ls s3://harbor/docker/registry/v2/repositories/inventory/podinfo/ >/dev/null 2>&1; then
  echo "FAIL: the bucket harbor holds no data for inventory/podinfo; the registry does not store in S3."
  exit 1
fi
echo "PASS: 20 pulls in a row of a freshly pushed artifact work, and the data is in the bucket harbor."
