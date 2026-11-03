# What A Database Dump Contains

Harbor stores projects, users, artifact records, tags and policies in the PostgreSQL database `registry`. If the database is lost and no dump exists, the image layers in the bucket have no names and no owners. This part takes a dump in the custom format and reads it without restoring it.

## Why the custom format

`pg_dump` can write plain SQL text or a custom-format archive. The option `-Fc` selects the archive. Only `pg_restore` can read an archive, and it can list the contents, restore one table, or restore with `--clean`. A plain SQL file can only be replayed whole with `psql`. For a backup that you want to inspect, use `-Fc`.

The folder `/backup` in the `postgres` pod is on a volume that outlives a dropped database, so the playground writes the dump there. Take the dump:

<!-- astrona:playground:renew -->

```sh
kubectl -n harbor-deps exec deploy/postgres -- pg_dump -U harbor -d registry -Fc -f /backup/registry.dump
kubectl -n harbor-deps exec deploy/postgres -- ls -l /backup
```

The listing shows the file `registry.dump` with a size above zero. A size above zero is not proof yet, so read what is in it.

## Read the archive without restoring it

The option `--list` prints the table of contents of the archive: every table, index and constraint, and one line of `TABLE DATA` per table that has rows.

```sh
kubectl -n harbor-deps exec deploy/postgres -- pg_restore --list /backup/registry.dump | grep 'TABLE DATA' | head
```

The lines name tables of Harbor, such as `project`, `artifact` and `harbor_user`. The option `-t` restores one table to standard output, which lets you look at real rows. Print the data of the table `project`:

```sh
kubectl -n harbor-deps exec deploy/postgres -- pg_restore -f - -t project /backup/registry.dump
```

The output is SQL that creates and fills the table. It includes the project `inventory`. If the dump had been taken before the image was pushed, that name would be missing, which is why the order of a backup matters.

## Compare with the live database

Count the rows in the live table and compare the number with the rows in the dump output above:

```sh
kubectl -n harbor-deps exec deploy/postgres -- psql -U harbor -d registry -tAc "select count(*) from project"
```

The count is the number of projects that Harbor has now. A dump is a snapshot of one moment. Anything pushed after it is not in it.

You now know that `-Fc` makes a dump that you can inspect, and that `--list` and `-t` prove what it contains. The database is only the names of things. The layers are in the bucket, which is the next part.

## Common pitfalls

> [!WARNING]
> - **Dumping without `-Fc`.** `pg_restore` cannot read plain SQL.
> - **Reading a non-zero file size as proof.** List the archive and look for `TABLE DATA`.
> - **Taking the dump before the content exists.** The restored Harbor lacks the newest projects.
> - **Keeping the only copy in the database pod's own volume.** Copy it out of the cluster as well.
