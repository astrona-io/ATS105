# Overview: Expose Harbor And Secure Its Traffic (Playground)

This is a **playground**, not a lab. It starts a fresh cluster with Harbor on external services and then waits. There is no task, no `astrona submit` and no pass or fail. Explore, break things, `astrona destroy`, start over.

## What's in the box

- A single-node `kind` cluster, with `kubectl` pointed at it and Helm 3.22.1 on your machine with the chart repository `harbor` added.
- **Harbor 2.15.4**, the release `harbor` (chart 1.19.4) in the namespace `harbor`, on the external PostgreSQL, Redis and S3 bucket `harbor` in the namespace `harbor-deps`, with job logs in the database. Each component runs **one** replica, and the traffic between the components is plain HTTP.
- The project `inventory` with `inventory/podinfo:6.15.0`.
- The Secret `harbor-tls` holds the certificate and the lab certificate authority. The `workstation` pod with `regctl`, `curl` and `jq`, trusting Harbor's certificate. The administrator is `admin` / `Harbor12345` (lab-only).

## Helpers

Paste these once in each new terminal. `ws` runs a command in the workstation. `core_port` prints the port `core` listens on. `pull_podinfo` downloads the whole image and prints `pull ok`.

```sh
ws() { kubectl -n workstation exec -i deploy/workstation -- "$@"; }
core_port() { kubectl -n harbor get configmap harbor-core -o jsonpath='{.data.PORT}{"\n"}'; }
pull_podinfo() {
  ws rm -rf /tmp/pull
  ws regctl image copy harbor.localtest.me:8443/inventory/podinfo:6.15.0 ocidir:///tmp/pull:6.15.0 && echo "pull ok"
}
ws regctl registry login harbor.localtest.me:8443 -u admin -p Harbor12345
```

## Practice tasks

- Read the certificate in `harbor-tls` with `openssl x509` and find the subject, the issuer and the expiry date.
- Fetch `/api/v2.0/systeminfo/getcert` and compare it with `ca.crt` in the Secret.
- Run `core_port`, enable `internalTLS` with `certSource: auto`, and run it again. List the Secrets that end in `internal-tls`.
- Request `https://harbor.localtest.me:8443/v2/` with `curl -i` from the workstation and read the `Www-Authenticate` header. Find the token realm and compare it with `externalURL`.
- Set `proxy.httpProxy` to an address that does not exist and read the `harbor-core` environment to see which variables the chart sets.
