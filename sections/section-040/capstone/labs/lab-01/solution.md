# Solution: Finish A Half-Done Database Move

Work the task yourself first. Running `astrona submit -c sections/section-040/capstone/labs/lab-01` after a step tells you which checks pass, without telling you what is left.

The grader checks four things: Harbor on `postgres-new` with the projects `inventory` and `inventory-late`, read-only mode off, `builds/old-builds` deleted with a real garbage collection run since the lab started, and a healthy Harbor.

## Step 1: Compare the two databases

```sh
kubectl -n harbor-deps exec deploy/postgres -- psql -U harbor -d registry -tAc 'select name from project order by name'
kubectl -n harbor-deps exec deploy/postgres-new -- psql -U harbor -d registry -tAc 'select name from project order by name'
```

The live server lists `builds`, `inventory`, `inventory-late` and `library`; the copy on `postgres-new` lacks `inventory-late`. The copy is older than the live data, so switching to it now would lose that project.

## Step 2: Take a fresh copy inside the read-only window

Harbor is already read-only, which is what the copy needs. Keep it that way while you copy:

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
harbor_api GET /configurations | ws jq -r '.read_only.value'
kubectl -n harbor-deps exec deploy/postgres -- pg_dump -U harbor -d registry -Fc -f /backup/registry.dump
kubectl -n harbor-deps exec deploy/postgres -- cat /backup/registry.dump \
  | kubectl -n harbor-deps exec -i deploy/postgres-new -- sh -c 'cat > /backup/registry.dump'
kubectl -n harbor-deps exec deploy/postgres -- wc -c /backup/registry.dump
kubectl -n harbor-deps exec deploy/postgres-new -- wc -c /backup/registry.dump
kubectl -n harbor-deps exec deploy/postgres-new -- pg_restore -U harbor -d registry --clean --if-exists /backup/registry.dump
```

The two `wc -c` lines must show the same size. If the copy is shorter, `kubectl exec` lost the end of the stream: run the copy again before `pg_restore`.

`read_only` is `true`. `--clean --if-exists` replaces the stale objects on `postgres-new` with the fresh ones.

## Step 3: Point Harbor at the new server

```sh
helm -n harbor get values harbor -o yaml > harbor-values.yaml
sed -i.bak 's/host: postgres.harbor-deps.svc.cluster.local/host: postgres-new.harbor-deps.svc.cluster.local/' harbor-values.yaml
helm upgrade harbor harbor/harbor --version 1.19.4 --namespace harbor \
  --values harbor-values.yaml --wait --timeout 20m
ws curl -s https://harbor.localtest.me:8443/api/v2.0/health | ws jq -r '.status'
```

## Step 4: Close the window and clean up

Deleting a repository is a write, so switch read-only mode off first:

```sh
harbor_api PUT /configurations '{"read_only":false}'
harbor_api DELETE /projects/builds/repositories/old-builds
harbor_api POST /system/gc/schedule '{"schedule":{"type":"Manual"},"parameters":{"delete_untagged":true,"dry_run":false}}'
sleep 30
harbor_api GET '/system/gc?page_size=1' | ws jq '.[0] | {job_status, job_parameters}'
```

The newest run shows `Success` with `"dry_run":false`. The layers of `old-builds` were pushed less than two hours ago, so this run skips them; a later run collects them. Then submit:

```sh
astrona submit -c sections/section-040/capstone/labs/lab-01
```

## Why the obvious shortcuts are wrong

| Shortcut | What happens |
| --- | --- |
| Switch to `postgres-new` as it is | The project `inventory-late` is lost; the grader refuses it |
| Switch read-only mode off before the copy | A push during the copy is lost again |
| Run only a dry run | Nothing is deleted; the grader needs a real run |
| Delete `old-builds` with read-only mode on | Harbor refuses the deletion |

## Common mistakes

- Trusting the existing copy without comparing it to the live database.
- Expecting the bucket to shrink at once: garbage collection skips blobs from the last two hours.
