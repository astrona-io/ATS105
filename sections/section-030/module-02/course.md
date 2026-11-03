# Check A Harbor Backup Before You Need It

A backup that was never read back is only a hope. Harbor spreads its state over a database, a bucket, two Secrets and the Helm values, and each piece can be missing, empty or in the wrong format without any error at the time of the copy. This module teaches how to take each part of the backup and how to prove, with a command, that it holds what a restore needs.

## What you will learn

- Take a custom-format dump of Harbor's database and read its contents without restoring it.
- Copy the bucket and compare the object counts of source and copy.
- Save the certificate, the CA, the `secretKey` and the Helm values where a restore can find them.
- Name what each missing piece breaks after a restore.

## Before you start

You need to know that Harbor keeps its metadata in PostgreSQL and its image layers in an S3 bucket, and basic `kubectl` use.

Your playground is a single-node `kind` cluster. **Harbor 2.15.4** runs there as the Helm release `harbor` in the namespace `harbor`, installed with chart 1.19.4 on the external PostgreSQL, Redis and S3 bucket in the namespace `harbor-deps`. The project `inventory` holds `inventory/podinfo:6.15.0`. The bucket `harbor-backup` and the folder `/backup` in the `postgres` pod are empty. The `workstation` pod in the namespace `workstation` holds `regctl`, `curl` and `jq`. The administrator is `admin` with the password `Harbor12345`; these are lab-only credentials.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->
