# Question

Solve this question on: `terminal`

**Time:** about 40 minutes · **Topic:** Upgrades and database migration

## Scenario

Harbor 2.15.2 (the release `harbor`, chart 1.19.2, namespace `harbor`) runs on the PostgreSQL server `postgres` in the namespace `harbor-deps`. The database team has built a new server, `postgres-new`, with an empty database `registry` and the same user and password, and wants Harbor on it this week. Security wants Harbor on 2.15.4. Pulls must keep working throughout; pushes may stop for a short window.

## Your task

1. Move Harbor's database from `postgres` to `postgres-new` without losing data. Stop writes while you copy, so nothing is written only to the old server.
2. Upgrade the release to chart `1.19.4` (Harbor 2.15.4), pointing at `postgres-new` (`postgres-new.harbor-deps.svc.cluster.local`).
3. When Harbor works on the new server, allow writes again.

## Constraints

- Keep every other Helm value as it is: the certificate, the URL, the Secrets, Redis and the bucket.
- Do not delete or change the database on `postgres`: it is the way back.
- Do not uninstall the release.

## Done when

- The release runs chart `harbor-1.19.4` with app version `2.15.4`.
- `database.external.host` is `postgres-new.harbor-deps.svc.cluster.local`, and the database there holds the project `inventory`.
- Read-only mode is off.
- `inventory/podinfo:6.15.0` pulls completely.
