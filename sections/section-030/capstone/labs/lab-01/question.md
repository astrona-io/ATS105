# Question

Solve this question on: `terminal`

**Time:** about 45 minutes · **Topic:** Backup and restore

## Scenario

Last night Harbor's database and image bucket were lost, and the on-call engineer restored Harbor from the backups. The release `harbor` runs again, its projects are back, but three things are wrong:

- Every tool in the `workstation` pod now refuses Harbor's certificate.
- `inventory/podinfo:6.15.0` is listed, but pulling it fails.
- The registry endpoint `mirror`, used for replication, can no longer sign in to its registry.

The backups are intact: the dump `/backup/registry.dump` in the `postgres` pod, the bucket `harbor-backup`, and the Secrets `harbor-tls` and `harbor-secretkey`, which are still in the namespace `harbor`. The database `registry` was restored correctly.

## Your task

Finish the restore so that Harbor serves its original certificate, uses its original `secretKey`, and serves every layer of its images again.

## Constraints

- Do not restore the database again: it is correct.
- Do not change the certificate in `harbor-tls` or the key in `harbor-secretkey`, and do not edit the endpoint `mirror`'s password.
- Do not uninstall the release.

## Done when

- Harbor serves the certificate from the Secret `harbor-tls`.
- Harbor uses `secretKey` from the Secret `harbor-secretkey`, and a ping of the endpoint `mirror` succeeds.
- `inventory/podinfo:6.15.0` pulls completely with its original digest.
- `/api/v2.0/health` reports every component `healthy`.
