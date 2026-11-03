# Plan And Check A Harbor Upgrade

A Harbor upgrade changes more than the images. The new version may add values to the chart and change the database schema, and the Harbor upgrade guide says the schema change cannot be undone. This module teaches how to read what an upgrade changes before you run it, how to take the backup that replaces a rollback, and how to prove that the upgraded Harbor works.

## What you will learn

- Tell the chart version from the application version and compare the values of two chart versions.
- Take a backup that fits the rule that there is no rollback.
- Upgrade the release with its installed values and watch the schema migration.
- Prove an upgrade with the chart version, the migration table and a pull.

## Before you start

You need Helm basics (`helm list`, `helm upgrade`, values files) and to know that Harbor keeps its metadata in PostgreSQL.

Your playground is a single-node `kind` cluster. **Harbor 2.15.2** runs there as the Helm release `harbor` in the namespace `harbor`, installed with chart 1.19.2 on the external PostgreSQL server `postgres`, Redis and S3 bucket in the namespace `harbor-deps`. A second, empty PostgreSQL server `postgres-new` also runs there. The project `inventory` holds `inventory/podinfo:6.15.0`. The `workstation` pod in the namespace `workstation` holds `regctl`, `curl` and `jq`. The administrator is `admin` with the password `Harbor12345`; these are lab-only credentials.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->
