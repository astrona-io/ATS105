#!/usr/bin/env bash
# Reference remediation, applied only by `astrona test` (the `testing:` block).
# `astrona run` never runs this. Taken from solution.md - if one changes, change the other.
set -euo pipefail

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

helm repo add harbor https://helm.goharbor.io >/dev/null 2>&1 || true
helm repo update harbor >/dev/null
kubectl -n harbor create secret generic harbor-database \
  --from-literal=password=harbor-db-password --dry-run=client -o yaml | kubectl apply -f -
cat > /tmp/ats105-harbor-values.yaml <<'EOF'
# Helm values for Harbor (chart harbor-helm) in this environment.
# One address everywhere: https://harbor.localtest.me:8443.
expose:
  type: clusterIP
  tls:
    enabled: true
    certSource: secret
    secret:
      secretName: harbor-tls
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
# The key Harbor uses to encrypt stored secrets. Back it up with the database.
existingSecretSecretKey: harbor-secretkey
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
    existingSecret: harbor-database
    sslmode: disable
redis:
  type: external
  external:
    addr: redis.harbor-deps.svc.cluster.local:6379
jobservice:
  jobLoggers:
    - database
EOF
helm upgrade harbor harbor/harbor --version 1.19.4 --namespace harbor \
  --values /tmp/ats105-harbor-values.yaml --wait --timeout 20m
kubectl -n harbor rollout restart deployment
kubectl -n harbor rollout status deployment/harbor-core --timeout=600s
wait_for_harbor
