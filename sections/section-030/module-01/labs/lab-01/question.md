# Question

Solve this question on: `terminal`

**Time:** about 40 minutes · **Topic:** Backup and restore

## Scenario

The auditors want proof that Harbor can be restored. The release `harbor` in the namespace `harbor` runs on the external services in `harbor-deps` and holds `inventory/podinfo:6.15.0`. You must back Harbor up, cause the disaster below, and restore it.

## Your task

1. **Back up** everything a restore needs, before you delete anything:
   - Harbor's database `registry` on `postgres` (the `postgres` pod has a folder `/backup` that survives a dropped database);
   - the image storage, the bucket `harbor`, into the bucket `harbor-backup`;
   - the Secrets `harbor-tls` and `harbor-secretkey`, and the Helm values of the release.
2. **Cause the disaster**, with exactly these commands:

   ```sh
   helm -n harbor uninstall harbor --wait
   kubectl -n harbor-deps exec deploy/postgres -- dropdb -U harbor --maintenance-db=postgres registry
   kubectl -n harbor-deps exec deploy/s3-client -- aws s3 rm s3://harbor --recursive
   ```

3. **Restore** Harbor as the release `harbor` in the namespace `harbor` (chart `harbor/harbor` version `1.19.4`), on the same database name, the same bucket, the same certificate and the same `secretKey`.

## Constraints

- Use the PostgreSQL server `postgres` and the bucket `harbor`; do not point Harbor elsewhere.
- Do not skip the disaster: the grader checks that the database `registry` was dropped and recreated, and that the release was installed again.

## Done when

- `inventory/podinfo:6.15.0` pulls completely with the digest it had before the disaster.
- Harbor reads its `secretKey` from the Secret `harbor-secretkey`.
- `/api/v2.0/health` reports every component `healthy`.
