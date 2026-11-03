# Question

Solve this question on: `terminal`

**Time:** about 30 minutes · **Topic:** Backup and restore

## Scenario

The auditors ask for a backup that can be checked before any disaster happens. The release `harbor` in the namespace `harbor` runs on the external services in `harbor-deps` and holds `inventory/podinfo:6.15.0`. No backup exists yet.

## Your task

Take a complete backup, and leave Harbor running:

1. Dump the database `registry` on `postgres` in the custom format to `/backup/registry.dump` in the `postgres` pod.
2. Copy the bucket `harbor` into the bucket `harbor-backup`.
3. Copy the certificate and the key of the Secret `harbor-tls`, its CA, and the `secretKey` of the Secret `harbor-secretkey` into one Secret named `harbor-backup-copy` in the namespace `harbor-deps`. Use the key names `tls.crt`, `tls.key`, `ca.crt` and `secretKey`.
4. Save the output of `helm get values harbor` in a ConfigMap named `harbor-values-backup` in `harbor-deps`, under the key `values.yaml`.

## Constraints

- Do not stop, uninstall or change the release `harbor`.
- Do not delete anything from the bucket `harbor`.

## Done when

- `pg_restore --list /backup/registry.dump` works and the dump holds the project `inventory`.
- The bucket `harbor-backup` holds as many objects as the bucket `harbor`.
- The Secret `harbor-backup-copy` and the ConfigMap `harbor-values-backup` match the live objects.
- `/api/v2.0/health` reports every component `healthy`.
