# Back Up And Restore Harbor

Restore Harbor's database from last night's dump onto a fresh installation and the portal looks perfect: every project, every repository, every tag. Then the first pull fails, because the database lists layers that are not in the new storage. Or every client refuses the connection, because the fresh installation made a new certificate. Or a replication rule fails, because the stored password can no longer be decrypted.

Each of those failures is a piece the backup left out. Keep one sentence in mind: **a Harbor backup is the database, the image storage and the secrets, taken together.** The database says what exists, the storage holds the bytes, and the secrets (the certificate and `secretKey`) let clients and Harbor itself read them.

The module has two parts. **What To Back Up** lists every piece, says what breaks without it, and shows how to take each one. **A Restore Drill** deletes Harbor's release, database and bucket on purpose and brings all of them back, proving the result with the original digest of an image. A graded lab follows the second part.

## Learning objectives

After this module you can:

- List the five pieces of a Harbor backup and say what breaks without each one.
- Back up Harbor's database with `pg_dump` and restore it with `pg_restore`.
- Copy Harbor's image storage to a backup bucket and back with `aws s3 sync`.
- Explain what `secretKey` encrypts and why the restored Harbor needs the same one.
- Keep Harbor's TLS certificate across a reinstall.
- Restore Harbor after its release, database and bucket are gone, and prove the result.
- Explain what Velero backs up and what it leaves to you.

## Before you start

You need to know where Harbor keeps its data: records in PostgreSQL, queues in Redis, images in the registry storage. You should be comfortable with `helm install`, `helm uninstall`, Secrets and `kubectl exec`.

Your playground is a single-node `kind` cluster with **Harbor 2.15.4** (chart 1.19.4), the release `harbor` in the namespace `harbor`, on the external services in the namespace `harbor-deps`:

| Workload | What it is |
| --- | --- |
| `postgres` | PostgreSQL 15.19 with Harbor's database `registry`; it has an empty folder `/backup` for dumps |
| `redis` | Redis 7.4.11 |
| `versitygw` (Service `s3`) | The S3 store with the bucket `harbor` (Harbor's images) and the empty bucket `harbor-backup` |
| `s3-client` | The AWS command-line tool, pointed at the store |

Harbor's certificate comes from the Secret `harbor-tls` and its `secretKey` from the Secret `harbor-secretkey`, both in the namespace `harbor`. The project `inventory` holds `inventory/podinfo:6.15.0`. The `workstation` pod holds `regctl`, `curl` and `jq` and trusts Harbor's certificate. The administrator is `admin` with the password `Harbor12345` (lab-only).

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->
