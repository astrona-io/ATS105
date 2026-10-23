#!/usr/bin/env bash
# Creates the starting state for ats-105-capstone-040.
#
# The fixed state is NOT created here; producing it is the task.
set -euo pipefail

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

wait_for_harbor || true
seed_content() {
  # Creates the project inventory and copies podinfo 6.15.0 into it.
  harbor_api POST /projects '{"project_name":"inventory","metadata":{"public":"false"}}' >/dev/null || true
  registry_login
  ws regctl image copy ghcr.io/stefanprodan/podinfo:6.15.0 harbor.localtest.me:8443/inventory/podinfo:6.15.0
}
seed_content
harbor_api POST /projects '{"project_name":"builds","metadata":{"public":"false"}}' >/dev/null || true
ws regctl image copy ghcr.io/stefanprodan/podinfo:6.14.1 harbor.localtest.me:8443/builds/old-builds:6.14.1
# An early copy of the database on postgres-new, taken before the project inventory-late existed.
kubectl -n harbor-deps exec deploy/postgres -- pg_dump -U harbor -d registry -Fc -f /backup/registry.dump
# Copy the dump through a local file and compare sizes: kubectl exec -i can
# drop the end of stdin, and pg_restore then reads a short or empty file.
DUMP_COPY="$(mktemp)"
kubectl -n harbor-deps exec deploy/postgres -- cat /backup/registry.dump > "$DUMP_COPY"
for _ in 1 2 3 4 5; do
  kubectl -n harbor-deps exec -i deploy/postgres-new -- sh -c 'cat > /backup/registry.dump' < "$DUMP_COPY"
  [ "$(kubectl -n harbor-deps exec deploy/postgres-new -- sh -c 'wc -c < /backup/registry.dump' | tr -d ' ')" = "$(wc -c < "$DUMP_COPY" | tr -d ' ')" ] && break
  sleep 1
done
rm -f "$DUMP_COPY"
kubectl -n harbor-deps exec deploy/postgres-new -- pg_restore -U harbor -d registry --clean --if-exists /backup/registry.dump
harbor_api POST /projects '{"project_name":"inventory-late","metadata":{"public":"false"}}' >/dev/null
harbor_api PUT /configurations '{"read_only":true}' >/dev/null
kubectl -n harbor-deps create configmap gc-baseline --from-literal=seeded-at="$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --dry-run=client -o yaml | kubectl apply -f -
echo "[lab] A database move was started and left half done. Finishing it is the task."
