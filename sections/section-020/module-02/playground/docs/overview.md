# Overview: Spread And Protect Harbor Replicas (Playground)

This is a **playground**, not a lab. It starts a fresh cluster with Harbor on external services and then waits. There is no task, no `astrona submit` and no pass or fail. Explore, break things, `astrona destroy`, start over.

## What's in the box

- A single-node `kind` cluster, with `kubectl` pointed at it and Helm 3.22.1 on your machine with the chart repository `harbor` added.
- **Harbor 2.15.4**, the release `harbor` (chart 1.19.4) in the namespace `harbor`, on the external PostgreSQL, Redis and S3 bucket `harbor` in the namespace `harbor-deps`, with job logs in the database. Each component runs **two** replicas, with no disruption budgets and no spread rules.
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

- Run `kubectl -n harbor get pods -o wide` and read the node of each replica.
- Enable `podDisruptionBudget` for `core`, upgrade, and read `kubectl -n harbor get pdb`.
- Set `minAvailable: 2` for `registry` and run `kubectl -n harbor drain <node> --dry-run=client --ignore-daemonsets --delete-emptydir-data`. Read the result and set it back.
- Add a hostname `topologySpreadConstraints` entry to `core` and watch the rollout with `kubectl -n harbor rollout status deployment/harbor-core`.
- Run `pull_podinfo` in a loop while you run `kubectl -n harbor rollout restart deployment/harbor-core`.
- Read `show max_connections` in PostgreSQL and compare it with `maxOpenConns` times the `core` replicas.
