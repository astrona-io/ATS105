#!/usr/bin/env bash
# PASS when every Harbor component has a PodDisruptionBudget that allows one disruption
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
    printf 'every Harbor component has a PodDisruptionBudget that allows one disruption' "$body" | ws curl -sS -u admin:Harbor12345 -X "$method" \
      -H 'Content-Type: application/json' --data-binary @- "$HARBOR_URL/api/v2.0$path"
  else
    ws curl -sS -u admin:Harbor12345 -X "$method" "$HARBOR_URL/api/v2.0$path"
  fi
}
harbor_status() {
  # harbor_status METHOD PATH [JSON]: prints only the HTTP status code.
  local method="$1" path="$2" body="${3:-}"
  if [ -n "$body" ]; then
    printf 'every Harbor component has a PodDisruptionBudget that allows one disruption' "$body" | ws curl -s -o /dev/null -w '%{http_code}' -u admin:Harbor12345 -X "$method" \
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

for component in portal core jobservice registry; do
  allowed="$(kubectl -n harbor get pdb "harbor-$component" -o jsonpath='{.status.disruptionsAllowed}' 2>/dev/null)"
  min_available="$(kubectl -n harbor get pdb "harbor-$component" -o jsonpath='{.spec.minAvailable}' 2>/dev/null)"
  if [ -z "$allowed" ]; then
    echo "FAIL: no PodDisruptionBudget named harbor-$component exists. Enable podDisruptionBudget for $component in the Helm values."
    exit 1
  fi
  if [ "$min_available" != "1" ]; then
    echo "FAIL: PodDisruptionBudget harbor-$component has minAvailable '$min_available'; it must be 1."
    exit 1
  fi
  if [ "$allowed" -lt 1 ]; then
    echo "FAIL: PodDisruptionBudget harbor-$component allows $allowed disruptions; at least 1 is required."
    exit 1
  fi
done
echo "PASS: portal, core, jobservice and registry each have a PodDisruptionBudget with minAvailable 1 that allows a disruption."
