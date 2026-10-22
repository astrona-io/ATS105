# Upgrade Harbor And Move Its Database

An upgrade of Harbor looks like any other `helm upgrade`, until it fails halfway. The new `core` has already changed the database tables, and `helm rollback` puts the old pods back on tables they no longer understand. A database move looks like a simple dump and restore, until someone pushes an image during the copy, and that image exists in the old database only.

Both problems have the same answer. Keep one sentence in mind: **protect the database before you change it.** Take a backup before every upgrade, because there is no way back except a restore, and stop writes during a database move, so the copy is complete.

The module has three parts. **Upgrading The Chart** follows the Harbor upgrade guide: what to check, what to back up, and why there is no rollback. **Moving The Database With A Read-Only Window** copies Harbor's database to a new server while read-only mode blocks pushes. A graded lab follows that part. **Garbage Collection After The Change** frees the storage that deleted images leave behind.

## Learning objectives

After this module you can:

- Follow the Harbor upgrade guide for Helm: back up, compare values, keep the certificate, upgrade.
- Explain why `helm rollback` is not supported for Harbor upgrades.
- Read Harbor's version from the API before and after an upgrade.
- Switch read-only mode on and off through the API and explain what it blocks.
- Move Harbor's database to a new PostgreSQL server without losing writes.
- Run garbage collection, read its history, and explain why it skips recent blobs.

## Before you start

You need to know where Harbor keeps its data and how to back up its database with `pg_dump` and restore it with `pg_restore`. You should be comfortable with `helm upgrade` with a values file.

Your playground is a single-node `kind` cluster with **Harbor 2.15.2**, installed with the `harbor-helm` chart **1.19.2** as the release `harbor` in the namespace `harbor`. It runs on the external services in the namespace `harbor-deps`:

| Workload | What it is |
| --- | --- |
| `postgres` | PostgreSQL 15.19 with Harbor's database `registry`; the server Harbor uses now |
| `postgres-new` | A second PostgreSQL 15.19 with an empty database `registry`; the new server |
| `redis` | Redis 7.4.11 |
| `versitygw` (Service `s3`) and `s3-client` | The S3 store with the bucket `harbor`, and the AWS command-line tool |

Both PostgreSQL pods have a folder `/backup` for dumps. Harbor's certificate comes from the Secret `harbor-tls`. The project `inventory` holds `inventory/podinfo:6.15.0`. The `workstation` pod holds `regctl`, `curl` and `jq` and trusts Harbor's certificate. The administrator is `admin` with the password `Harbor12345` (lab-only).

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->
