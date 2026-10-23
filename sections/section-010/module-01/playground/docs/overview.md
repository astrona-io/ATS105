# Overview: Run Harbor On External Services (Playground)

This is a **playground**, not a lab. It starts a fresh cluster, installs Harbor and the external services next to it, and then waits. There is no task, no `astrona submit` and no pass or fail. Explore, break things, `astrona destroy`, start over.

## What's in the box

- A single-node `kind` Kubernetes cluster. `kubectl` is already pointed at it, and Helm 3.22.1 is on your machine with the chart repository `harbor` added.
- **Harbor 2.15.4**, the Helm release `harbor` (chart 1.19.4) in the namespace `harbor`, on its **internal** PostgreSQL and Redis and with filesystem storage on an `emptyDir`. It answers at `https://harbor.localtest.me:8443` with a certificate from the Secret `harbor-tls`.
- The Secrets `harbor-secretkey`, `harbor-external-db` (key `password`) and `harbor-s3` (keys `REGISTRY_STORAGE_S3_ACCESSKEY` and `REGISTRY_STORAGE_S3_SECRETKEY`) in the namespace `harbor`, ready to use.
- The namespace **`harbor-deps`**:

  | Workload | What it is |
  | --- | --- |
  | `postgres` | PostgreSQL 15.19, user `harbor`, password `harbor-db-password`, empty database `registry` |
  | `redis` | Redis 7.4.11 on port `6379`, no password |
  | `versitygw` (Service `s3`) | S3-compatible store on port `9000`, empty bucket `harbor` |
  | `s3-client` | The AWS command-line tool, pointed at the store |

- The **`workstation`** pod in the namespace `workstation`, with `harbor`, `regctl`, `oras`, `cosign`, `curl` and `jq`, trusting Harbor's certificate. The administrator is `admin` / `Harbor12345` (lab-only).

## Helpers

Paste these once in each new terminal. `ws` runs a command in the workstation. `harbor_health` prints each component and its status. `bucket_ls` lists a path in the bucket `harbor`. `harbor_tables` lists the tables in the external database.

```sh
ws() { kubectl -n workstation exec -i deploy/workstation -- "$@"; }
harbor_health() {
  ws curl -s https://harbor.localtest.me:8443/api/v2.0/health | ws jq -r '.components[] | "\(.name) \(.status)"'
}
bucket_ls() { kubectl -n harbor-deps exec deploy/s3-client -- aws s3 ls "s3://harbor/$1"; }
harbor_tables() { kubectl -n harbor-deps exec deploy/postgres -- psql -U harbor -d registry -c '\dt'; }
```

Use them like this: `harbor_health`, `bucket_ls docker/registry/v2/`, `harbor_tables`.

To open the web portal, run `kubectl -n harbor port-forward svc/harbor 8443:8443` in a second terminal and browse to `https://harbor.localtest.me:8443`. The browser warns about the lab certificate.

## Practice tasks

- Before you change anything, find every StatefulSet in the namespace `harbor` and say what data each one holds.
- Move only the database to `postgres` and run `harbor_tables` before and after. Then move Redis and storage too.
- Set `existingSecret` to a Secret that has the password under the key `db-password` instead of `password`, and read the `harbor-core` logs to see what Harbor reports.
- Push `podinfo` into the project `inventory` and find its layers with `bucket_ls docker/registry/v2/blobs/`.
- Switch storage back to `filesystem` and try to pull the image you pushed before. Explain the result.
