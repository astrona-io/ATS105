# Section 040: Upgrades And Database Migration

Every registry gets upgraded, and most of them move to a new database server at least once. Both changes touch the one thing Harbor cannot rebuild: its database. An upgrade can change the database schema in a way that cannot be undone, and a database move that copies the data while pushes continue loses whatever arrived during the copy.

This section upgrades Harbor with the chart, moves its database to a new PostgreSQL server inside a read-only window, and frees storage afterwards with garbage collection.

**Topic covered:** Upgrades and database migration

## What you will learn

- The upgrade checklist from the Harbor guide, and why `helm rollback` is not supported.
- Comparing two chart versions' defaults before you upgrade.
- What read-only mode blocks and allows, and how to switch it on and off through the API.
- Moving the database to a new PostgreSQL server with `pg_dump` and `pg_restore`, without losing writes.
- What garbage collection deletes, what it skips, and how to run it and read its history.

## The learning path

### 1. Upgrade Harbor And Move Its Database

The playground holds Harbor 2.15.2 (chart 1.19.2) on the PostgreSQL server `postgres`, with the image `inventory/podinfo:6.15.0`, and a second, empty PostgreSQL server `postgres-new`.

1. Upgrading The Chart
2. Moving The Database With A Read-Only Window, followed by the lab **Upgrade Harbor And Move Its Database**
3. Garbage Collection After The Change
4. Summary

## Section capstone: Finish A Half-Done Database Move

A database move was started on Friday and left half done. Harbor still runs on the old server, a stale copy sits on the new one, Harbor is stuck in read-only mode, and an old repository was never cleaned up. Work the capstone after the module lab.

Start the capstone:

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS105.git -c sections/section-040/capstone/labs/lab-01
```

When you think you are done, send it for grading:

```sh
astrona submit -c sections/section-040/capstone/labs/lab-01
```

When the capstone is done, remove it:

```sh
astrona destroy ats-105-capstone-040
```
