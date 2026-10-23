#!/usr/bin/env bash
# Creates the starting state for ats-105-capstone-030.
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
# A registry endpoint whose password Harbor stores encrypted with secretKey.
harbor_api POST /registries '{"name":"mirror","type":"docker-registry","url":"http://mirror.harbor-deps.svc.cluster.local:5000","credential":{"type":"basic","access_key":"mirror","access_secret":"mirror-password"},"insecure":true}' >/dev/null
DIGEST="$(ws regctl image digest harbor.localtest.me:8443/inventory/podinfo:6.15.0)"
kubectl -n harbor-deps create configmap restore-baseline --from-literal=digest="$DIGEST" \
  --dry-run=client -o yaml | kubectl apply -f -

# A backup, then a disaster, then a hurried restore from memory.
kubectl -n harbor-deps exec deploy/postgres -- pg_dump -U harbor -d registry -Fc -f /backup/registry.dump
s3 sync s3://harbor s3://harbor-backup >/dev/null
helm -n harbor uninstall harbor --wait
kubectl -n harbor-deps exec deploy/postgres -- dropdb -U harbor --maintenance-db=postgres registry
s3 rm s3://harbor --recursive >/dev/null
kubectl -n harbor-deps exec deploy/postgres -- createdb -U harbor --maintenance-db=postgres registry
kubectl -n harbor-deps exec deploy/postgres -- pg_restore -U harbor -d registry /backup/registry.dump
cat > /tmp/ats105-hurried-values.yaml <<'EOF'
# Helm values for Harbor (chart harbor-helm) in this environment.
# One address everywhere: https://harbor.localtest.me:8443.
expose:
  type: clusterIP
  tls:
    enabled: true
    certSource: auto
    auto:
      commonName: harbor.localtest.me
  clusterIP:
    name: harbor
    ports:
      httpPort: 8080
      httpsPort: 8443
externalURL: https://harbor.localtest.me:8443
# Lets Harbor serve the CA at /api/v2.0/systeminfo/getcert.
caSecretName: harbor-tls
# Lab-only administrator password. A real installation sets its own.
harborAdminPassword: Harbor12345
persistence:
  enabled: false
  imageChartStorage:
    # The registry cannot send clients to the S3 endpoint inside the cluster.
    disableredirect: true
    type: s3
    s3:
      existingSecret: harbor-s3
      region: us-east-1
      bucket: harbor
      regionendpoint: http://s3.harbor-deps.svc.cluster.local:9000
      v4auth: true
trivy:
  enabled: false
metrics:
  enabled: false
database:
  type: external
  external:
    host: postgres.harbor-deps.svc.cluster.local
    port: "5432"
    username: harbor
    coreDatabase: registry
    existingSecret: harbor-external-db
    sslmode: disable
redis:
  type: external
  external:
    addr: redis.harbor-deps.svc.cluster.local:6379
jobservice:
  jobLoggers:
    - database
EOF
helm install harbor harbor/harbor --version 1.19.4 --namespace harbor \
  --values /tmp/ats105-hurried-values.yaml --wait --timeout 20m
rm -f /tmp/ats105-hurried-values.yaml
echo "[lab] Harbor was restored in a hurry. Finding what the restore got wrong is the task."
