#!/usr/bin/env bash
# OS prep for the "Run Harbor With High Availability" playground (`ats-105-playground-020-01`).
#
# Environment preparation only. There is no task and no grading.
set -euo pipefail

HELM_VERSION="3.22.1"
BIN_DIR="/usr/local/bin"
[ -w "$BIN_DIR" ] || BIN_DIR="$HOME/.local/bin"
mkdir -p "$BIN_DIR"
export PATH="$BIN_DIR:$PATH"

# Pin Helm rather than accepting whatever is on the machine: the Harbor
# documentation is written for Helm 3.
have_version=""
command -v helm >/dev/null 2>&1 && \
  have_version=$(helm version --template '{{.Version}}' 2>/dev/null | sed 's/^v//')
if [ "$have_version" != "$HELM_VERSION" ]; then
  OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
  ARCH="$(uname -m)"
  case "$ARCH" in x86_64) ARCH=amd64 ;; aarch64|arm64) ARCH=arm64 ;; esac
  HELM_WORK="$(mktemp -d)"
  echo "[playground] Downloading Helm ${HELM_VERSION} (${OS}/${ARCH})..."
  curl -fsSL "https://get.helm.sh/helm-v${HELM_VERSION}-${OS}-${ARCH}.tar.gz" | tar -xz -C "$HELM_WORK"
  install -m 0755 "$HELM_WORK/${OS}-${ARCH}/helm" "$BIN_DIR/helm"
  rm -rf "$HELM_WORK"
fi
helm version --short

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST_DIR=""
for candidate in "$SCRIPT_DIR/../manifests" "./manifests" "$SCRIPT_DIR/manifests"; do
  [ -d "$candidate" ] && { MANIFEST_DIR="$candidate"; break; }
done
[ -n "$MANIFEST_DIR" ] || { echo "[playground] ERROR: manifests directory not found." >&2; exit 1; }

# One address for the reader's machine and the cluster: harbor.localtest.me
# resolves to 127.0.0.1 on the machine (reached through a port-forward), and
# this CoreDNS block sends the same name to the Harbor Service in the cluster.
# The answer is rewritten back to the asked name: Go programs ignore DNS
# answers whose name differs from the question.
if ! kubectl -n kube-system get configmap coredns -o jsonpath='{.data.Corefile}' | grep -q "harbor.localtest.me"; then
  echo "[playground] Adding the CoreDNS rewrite for harbor.localtest.me..."
  COREFILE="$(kubectl -n kube-system get configmap coredns -o jsonpath='{.data.Corefile}' \
    | awk '/^[[:space:]]*kubernetes / && !done {
        print "    rewrite stop {"
        print "        name regex harbor\\.localtest\\.me harbor.harbor.svc.cluster.local"
        print "        answer name harbor\\.harbor\\.svc\\.cluster\\.local harbor.localtest.me"
        print "    }"
        done=1
      } {print}')"
  kubectl -n kube-system create configmap coredns --from-literal=Corefile="$COREFILE" \
    --dry-run=client -o yaml | kubectl apply -f -
  kubectl -n kube-system rollout restart deployment/coredns
  kubectl -n kube-system rollout status deployment/coredns --timeout=120s
fi

# The external services Harbor uses in this course: PostgreSQL, Redis and an
# S3-compatible object store, all in the namespace harbor-deps.
echo "[playground] Starting the external services in harbor-deps..."
kubectl apply -f "$MANIFEST_DIR/harbor-deps.yaml"
for deployment in $(kubectl -n harbor-deps get deployment -o name); do
  kubectl -n harbor-deps rollout status "$deployment" --timeout=300s
done
for bucket in harbor; do
  kubectl -n harbor-deps exec deploy/s3-client -- aws s3 mb "s3://$bucket" >/dev/null 2>&1 || true
done

# Harbor's TLS certificate comes from the Secret harbor-tls, not from the
# chart's automatic certificate: an upgrade or a reinstall regenerates an
# automatic certificate, and backups, restores and upgrades must keep it.
kubectl create namespace harbor --dry-run=client -o yaml | kubectl apply -f -
if ! kubectl -n harbor get secret harbor-tls >/dev/null 2>&1; then
  echo "[playground] Creating the lab certificate authority and Harbor's certificate..."
  TLS_WORK="$(mktemp -d)"
  cat > "$TLS_WORK/ca.cnf" <<'CNF'
[req]
distinguished_name = dn
[dn]
[v3_ca]
basicConstraints = critical,CA:TRUE
keyUsage = critical,keyCertSign,cRLSign
subjectKeyIdentifier = hash
CNF
  printf 'subjectAltName=DNS:harbor.localtest.me\nextendedKeyUsage=serverAuth\n' > "$TLS_WORK/server.ext"
  openssl genrsa -out "$TLS_WORK/ca.key" 2048 2>/dev/null
  openssl req -x509 -new -key "$TLS_WORK/ca.key" -days 365 -subj "/CN=Harbor Lab CA" \
    -config "$TLS_WORK/ca.cnf" -extensions v3_ca -out "$TLS_WORK/ca.crt"
  openssl genrsa -out "$TLS_WORK/tls.key" 2048 2>/dev/null
  openssl req -new -key "$TLS_WORK/tls.key" -subj "/CN=harbor.localtest.me" \
    -config "$TLS_WORK/ca.cnf" -out "$TLS_WORK/tls.csr"
  openssl x509 -req -in "$TLS_WORK/tls.csr" -CA "$TLS_WORK/ca.crt" -CAkey "$TLS_WORK/ca.key" \
    -CAcreateserial -days 365 -extfile "$TLS_WORK/server.ext" -out "$TLS_WORK/tls.crt" 2>/dev/null
  kubectl -n harbor create secret generic harbor-tls \
    --from-file=tls.crt="$TLS_WORK/tls.crt" --from-file=tls.key="$TLS_WORK/tls.key" \
    --from-file=ca.crt="$TLS_WORK/ca.crt"
  rm -rf "$TLS_WORK"
fi

# Lab-only credentials, kept in Secrets so the Helm values never hold them.
kubectl -n harbor create secret generic harbor-secretkey \
  --from-literal=secretKey=lab-secretkey-16 --dry-run=client -o yaml | kubectl apply -f -
kubectl -n harbor create secret generic harbor-database \
  --from-literal=password=harbor-db-password --dry-run=client -o yaml | kubectl apply -f -
kubectl -n harbor create secret generic harbor-s3 \
  --from-literal=REGISTRY_STORAGE_S3_ACCESSKEY=harbor-s3 \
  --from-literal=REGISTRY_STORAGE_S3_SECRETKEY=harbor-s3-secret \
  --dry-run=client -o yaml | kubectl apply -f -

echo "[playground] Installing Harbor (chart 1.19.4); this takes several minutes..."
helm repo add harbor https://helm.goharbor.io >/dev/null 2>&1 || true
helm repo update harbor >/dev/null
helm upgrade --install harbor harbor/harbor --version "1.19.4" \
  --namespace harbor --values "$MANIFEST_DIR/harbor-values.yaml" \
  --wait --timeout 20m

# lab-start.yaml may already be applied through config.yaml; apply is idempotent.
echo "[playground] Starting the workstation pod..."
kubectl apply -f "$MANIFEST_DIR/lab-start.yaml"
kubectl -n workstation rollout status deployment/workstation --timeout=600s
for _ in $(seq 1 60); do
  kubectl -n workstation exec deploy/workstation -- test -s /usr/local/share/ca-certificates/harbor-ca.crt 2>/dev/null && break
  sleep 5
done

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
echo "[playground] Harbor runs on the external services with one replica per component."
echo "[playground] Ready."
kubectl -n harbor get pods
echo "[playground] Run tools in the workstation: kubectl -n workstation exec -it deploy/workstation -- sh"
