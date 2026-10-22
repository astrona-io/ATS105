# Overview: Back Up And Restore Harbor (Playground)

This is a **playground**, not a lab. It starts a fresh cluster with Harbor on external services and one image, and then waits. There is no task, no `astrona submit` and no pass or fail. Explore, break things, `astrona destroy`, start over.

## What's in the box

- A single-node `kind` cluster, with `kubectl` pointed at it and Helm 3.22.1 on your machine with the chart repository `harbor` added.
- **Harbor 2.15.4**, the release `harbor` (chart 1.19.4) in the namespace `harbor`, on the external PostgreSQL, Redis and S3 bucket `harbor` in the namespace `harbor-deps`. The certificate comes from the Secret `harbor-tls` and `secretKey` from the Secret `harbor-secretkey`.
- The project `inventory` with `inventory/podinfo:6.15.0`.
- The empty bucket `harbor-backup`, and the empty folder `/backup` in the `postgres` pod.
- The `workstation` pod with `regctl`, `curl` and `jq`, trusting Harbor's certificate. The administrator is `admin` / `Harbor12345` (lab-only).

## Helpers

Paste these once in each new terminal. `ws` runs a command in the workstation. `on_postgres` runs a command in the `postgres` pod. `s3` runs `aws s3` in the client pod. `podinfo_digest` prints the digest of `inventory/podinfo:6.15.0`.

```sh
ws() { kubectl -n workstation exec -i deploy/workstation -- "$@"; }
on_postgres() { kubectl -n harbor-deps exec -i deploy/postgres -- "$@"; }
s3() { kubectl -n harbor-deps exec -i deploy/s3-client -- aws s3 "$@"; }
podinfo_digest() {
  ws regctl registry login harbor.localtest.me:8443 -u admin -p Harbor12345 >/dev/null
  ws regctl image digest harbor.localtest.me:8443/inventory/podinfo:6.15.0
}
```

Use them like this: `on_postgres ls -l /backup`, `s3 ls s3://harbor-backup`, `podinfo_digest`.

## Practice tasks

- Take a database dump but no storage copy, run the disaster, and restore. Predict what `podinfo_digest` and a full pull each say.
- Restore everything but delete the Secret `harbor-tls` first, so the chart makes a new certificate. See what `regctl` in the workstation reports.
- Push a new tag after the dump but before the storage copy, then restore. Which of the two tags comes back complete?
- Time the whole drill. That number is your recovery time.
