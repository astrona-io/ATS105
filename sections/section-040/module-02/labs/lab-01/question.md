# Question

Solve this question on: `terminal`

**Time:** about 30 minutes · **Topic:** Upgrades

## Scenario

Harbor 2.15.2 (the release `harbor`, chart 1.19.2, namespace `harbor`) runs on the PostgreSQL server `postgres` in the namespace `harbor-deps`. Security wants Harbor on 2.15.4. The Harbor upgrade guide says that an upgrade changes the database schema and that there is no rollback, so the change board asks for a backup first.

## Your task

1. Take a custom-format dump of the database `registry` on `postgres` to `/backup/registry.dump` in the `postgres` pod, before you change anything.
2. Upgrade the release to chart `1.19.4` (Harbor 2.15.4) in place, on the same database server.

## Constraints

- Keep every Helm value as it is: the certificate, the URL, the Secrets, the database, Redis and the bucket.
- Do not uninstall the release.
- Do not delete or change anything in the databases.

## Done when

- `/backup/registry.dump` is a valid custom-format dump that is older than the upgraded `core` pods.
- The release runs chart `harbor-1.19.4` with app version `2.15.4`.
- `database.external.host` is still `postgres.harbor-deps.svc.cluster.local`.
- Read-only mode is off, and `inventory/podinfo:6.15.0` pulls completely.
