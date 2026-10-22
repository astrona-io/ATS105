# Overview: Run Harbor With High Availability (Playground)

This is a **playground**, not a lab. It starts a fresh cluster with Harbor on external services and then waits. There is no task, no `astrona submit` and no pass or fail. Explore, break things, `astrona destroy`, start over.

## What's in the box

- A single-node `kind` cluster, with `kubectl` pointed at it and Helm 3.22.1 on your machine with the chart repository `harbor` added.
- **Harbor 2.15.4**, the release `harbor` (chart 1.19.4) in the namespace `harbor`, on the external PostgreSQL, Redis and S3 bucket `harbor` in the namespace `harbor-deps`, with job logs in the database. Each component runs **one** replica.
- The project `inventory` with `inventory/podinfo:6.15.0`.
- The `workstation` pod with `regctl`, `curl` and `jq`, trusting Harbor's certificate. The administrator is `admin` / `Harbor12345` (lab-only).

## Helpers

Paste these once in each new terminal. `ws` runs a command in the workstation. `pull_podinfo` downloads the whole image, all layers, and prints `pull ok`. `kill_one` deletes one pod of a component without waiting.

```sh
ws() { kubectl -n workstation exec -i deploy/workstation -- "$@"; }
pull_podinfo() {
  ws rm -rf /tmp/pull
  ws regctl image copy harbor.localtest.me:8443/inventory/podinfo:6.15.0 ocidir:///tmp/pull:6.15.0 && echo "pull ok"
}
kill_one() {
  kubectl -n harbor delete pod "$(kubectl -n harbor get pods -l component="$1" -o name | head -1 | cut -d/ -f2)" --wait=false
}
ws regctl registry login harbor.localtest.me:8443 -u admin -p Harbor12345
```

Use them like this: `pull_podinfo`, `kill_one registry && pull_podinfo`.

## Practice tasks

- With one replica each, run `kill_one registry && pull_podinfo` and note what happens. Then scale and run it again.
- Scale `registry` to two replicas but switch its storage back to `filesystem`. Push a new tag and pull it ten times. Count the failures and explain them.
- Scale `jobservice` with `jobLoggers` set to `file`, start a garbage collection dry run in the portal, and try to open its log.
- Delete both `core` pods at once and see what a pull does while they come back.
