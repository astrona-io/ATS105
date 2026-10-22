# Summary

Upgrades and database moves both change the one thing Harbor cannot rebuild. This module showed how to do each one without losing data, and how to free the storage that deletions leave behind.

## What you learned

The Harbor upgrade guide for Helm has four steps: back up the database, get the new chart, configure it with the same values, and run `helm upgrade`. A newer Harbor may migrate the database schema when it starts, and that migration only goes forward, so `helm rollback` is not supported; the way back is a database restore and the old chart. Comparing `helm show values` of the two chart versions shows every default that changed. A chart-generated certificate is replaced by an upgrade, so the certificate belongs in a Secret of your own. Harbor's version is in `/api/v2.0/systeminfo`.

Read-only mode allows pulls and refuses pushes and deletions. It is the setting `read_only` in Harbor's configuration, read and changed through `/api/v2.0/configurations`. A database move opens a read-only window, dumps the old server with `pg_dump`, restores the new one with `pg_restore`, changes `database.external.host`, checks Harbor, and closes the window. The old server stays untouched until the new one has proven itself.

Deleting an artifact removes its records, not its blobs. Garbage collection, a `jobservice` job, deletes blobs that no manifest references. It skips anything from the last two hours, does not need read-only mode, runs at most once per minute, and offers a dry run that reports what a real run would delete. The key facts to remember are these:

- Back up the database before every upgrade; there is no rollback.
- Stop writes with read-only mode before you dump a database you are moving, and switch it off when Harbor passes its checks.
- Garbage collection, not deletion, frees storage, and only for blobs older than two hours.

<!-- astrona:playground:destroy -->
