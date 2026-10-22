# Question

Solve this question on: `terminal`

**Time:** about 45 minutes · **Topic:** Upgrades and database migration

## Scenario

On Friday a colleague started moving Harbor's database from `postgres` to `postgres-new` in the namespace `harbor-deps`, and then went home. Today:

- Harbor (the release `harbor`, chart 1.19.4) still runs on `postgres`.
- `postgres-new` holds a copy of Harbor's database, but nobody knows how old it is.
- Users report that every push fails with a message about read only mode.
- The project `builds` still holds the repository `old-builds`, which the team asked to delete and whose storage should be freed.

## Your task

1. Finish the move: Harbor must run on `postgres-new` (`postgres-new.harbor-deps.svc.cluster.local`) with **all** of its current data.
2. Leave Harbor writable.
3. Delete the repository `builds/old-builds` and run garbage collection (not a dry run) so its storage can be freed.

## Constraints

- Do not delete or change the database on `postgres`.
- Keep every other Helm value as it is.
- Do not uninstall the release.

## Done when

- `database.external.host` is `postgres-new.harbor-deps.svc.cluster.local`, and the database there holds the projects `inventory` and `inventory-late`.
- Read-only mode is off.
- `builds/old-builds` does not exist, and a garbage collection run that is not a dry run has succeeded since the lab started.
- `/api/v2.0/health` reports every component `healthy`.
