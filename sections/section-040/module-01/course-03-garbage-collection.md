# Garbage Collection After The Change

Deleting a repository in Harbor removes it from the portal and the database, but the layers stay in the bucket. Harbor does not free storage when you delete; it frees storage when garbage collection runs. After a migration, a cleanup of old repositories or a retention policy, garbage collection is the step that actually gives the space back.

## What garbage collection does

Garbage collection (GC) is a job that `jobservice` runs. It looks for blobs, the layer and manifest files in the registry storage, that no remaining manifest references, and deletes them. The Harbor documentation on garbage collection adds four facts that decide what a run really does:

- **Deleted artifacts first.** Deleting an artifact or a repository only removes the records. The blobs become garbage, and the next GC run collects them.
- **Untagged artifacts.** With the option to delete untagged artifacts, GC first deletes artifacts that have no tag, then collects their blobs.
- **A two-hour window.** GC skips manifests and blobs whose timestamps are within the last two hours, so it never removes layers of a push that is still in progress.
- **No read-only mode needed.** Pushes, pulls and deletions keep working while GC runs.

A **dry run** goes through the same steps without deleting anything and reports how much space a real run would free. You can schedule GC (hourly, daily, weekly or with a cron expression) or run it now, and every run leaves an entry in the GC history with its status and log.

## Delete a repository and collect it

The playground's project `inventory` holds `podinfo`. Copy a second image into a throwaway repository, delete it, and run GC. Start with the helpers and the size of the bucket:

<!-- astrona:playground:renew -->

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
kubectl -n harbor-deps exec deploy/s3-client -- aws s3 ls s3://harbor --recursive --summarize | tail -2
```

The last two lines give the number of objects and the total size of the bucket. Now add and delete a repository:

```sh
ws regctl registry login harbor.localtest.me:8443 -u admin -p Harbor12345
ws regctl image copy ghcr.io/stefanprodan/podinfo:6.14.1 harbor.localtest.me:8443/inventory/old-builds:6.14.1
harbor_api DELETE /projects/inventory/repositories/old-builds
```

The repository is gone from Harbor, but its layers are still in the bucket. Start a dry run first, through the GC schedule endpoint with the type `Manual`, which means "run once, now":

```sh
harbor_api POST /system/gc/schedule '{"schedule":{"type":"Manual"},"parameters":{"delete_untagged":true,"dry_run":true}}'
sleep 20
harbor_api GET '/system/gc?page_size=1' | ws jq '.[0] | {job_status, job_parameters, creation_time}'
```

The newest history entry shows the run with `"dry_run":true` in its parameters and a `job_status` of `Success` when it has finished. Its log, which you can read with `harbor_api GET /system/gc/<id>/log` using the `id` from the history, lists what a real run would delete.

Then run it for real:

```sh
harbor_api POST /system/gc/schedule '{"schedule":{"type":"Manual"},"parameters":{"delete_untagged":true,"dry_run":false}}'
sleep 20
harbor_api GET '/system/gc?page_size=1' | ws jq '.[0] | {job_status, job_parameters}'
kubectl -n harbor-deps exec deploy/s3-client -- aws s3 ls s3://harbor --recursive --summarize | tail -2
```

The run succeeds. Whether the bucket shrinks depends on the two-hour window: the layers of `old-builds` were pushed a minute ago, so GC skips them and the size stays the same. On a real Harbor, where deleted images are older than two hours, the same run frees their space. GC can only run once per minute, so wait a minute between runs.

You now know how Harbor frees storage: deleting removes the records, and garbage collection, after a dry run and outside the two-hour window, removes the blobs. Together with backups before upgrades and read-only windows for database moves, it completes the routine of keeping a Harbor healthy over time.

## Common pitfalls

> [!WARNING]
> - **Expecting a deletion to free space.** Only garbage collection deletes blobs.
> - **Expecting fresh blobs to disappear.** GC skips anything from the last two hours.
> - **Running GC for real without a dry run first.** The dry run shows what will go; a real run cannot be undone.
> - **Starting two runs in a row.** GC runs at most once per minute.
