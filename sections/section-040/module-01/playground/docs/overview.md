# Overview: Upgrade Harbor And Move Its Database (Playground)

This is a **playground**, not a lab. It starts a fresh cluster with an older Harbor and a second, empty PostgreSQL server, and then waits. There is no task, no `astrona submit` and no pass or fail. Explore, break things, `astrona destroy`, start over.

## What's in the box

- A single-node `kind` cluster, with `kubectl` pointed at it and Helm 3.22.1 on your machine with the chart repository `harbor` added.
- **Harbor 2.15.2**, the release `harbor` installed with chart **1.19.2** in the namespace `harbor`, on the PostgreSQL server `postgres`, Redis and the S3 bucket `harbor` in the namespace `harbor-deps`. The certificate comes from the Secret `harbor-tls`.
- **`postgres-new`**, a second PostgreSQL 15.19 server with an empty database `registry`, same user and password. Both PostgreSQL pods have a folder `/backup`.
- The project `inventory` with `inventory/podinfo:6.15.0`.
- The `workstation` pod with `regctl`, `curl` and `jq`, trusting Harbor's certificate. The administrator is `admin` / `Harbor12345` (lab-only).

## Helpers

Paste these once in each new terminal. `ws` runs a command in the workstation. `harbor_api` calls Harbor's API as the administrator, with an optional JSON body. `harbor_version` prints Harbor's version, and `read_only` prints whether read-only mode is on.

```sh
ws() { kubectl -n workstation exec -i deploy/workstation -- "$@"; }
harbor_api() {
  if [ -n "${3:-}" ]; then
    ws curl -sS -u admin:Harbor12345 -X "$1" -H 'Content-Type: application/json' \
      --data "$3" "https://harbor.localtest.me:8443/api/v2.0$2"
  else
    ws curl -sS -u admin:Harbor12345 -X "$1" "https://harbor.localtest.me:8443/api/v2.0$2"
  fi
}
harbor_version() { harbor_api GET /systeminfo | ws jq -r '.harbor_version'; }
read_only() { harbor_api GET /configurations | ws jq -r '.read_only.value'; }
```

Use them like this: `harbor_version`, `read_only`, `harbor_api PUT /configurations '{"read_only":true}'`.

## Practice tasks

- Switch read-only mode on and try to push a new tag with `regctl`. Read the error. Then try a pull.
- Compare the default values of chart 1.19.2 and 1.19.4 and list every line that is not an image tag.
- Dump the database without read-only mode, push a new project, then restore the dump on `postgres-new`. Find the project that is missing.
- Delete a repository and run a garbage collection dry run. Read its log with `harbor_api GET /system/gc/<id>/log`.
