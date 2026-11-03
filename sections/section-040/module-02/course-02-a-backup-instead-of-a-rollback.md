# A Backup Instead Of A Rollback

With most applications, an upgrade that goes wrong is undone with `helm rollback`. The Harbor upgrade guide says that Harbor does not support this. A new Harbor version migrates the database schema when it starts, and the schema cannot be downgraded. This part explains what that means for the plan and takes the backup that takes the place of a rollback.

## Why there is no rollback

`helm rollback` re-applies the templates and values of an earlier revision, so the old images start again. The database, however, now has the new schema. An old `core` that starts on a newer schema can refuse to start or misread data. The only way back is a restore of the data from before the upgrade, together with the old chart.

You can see the revisions Helm keeps, but remember that they describe the objects in the cluster and not the data:

<!-- astrona:playground:renew -->

```sh
helm -n harbor history harbor
```

The history shows one revision with the status `deployed`. After an upgrade it shows two.

## What the backup must hold

A restore needs the database, the bucket, the certificate and `secretKey` Secrets, and the Helm values. For an upgrade, the database dump is the part that matters most, because the upgrade changes only the database schema. Take a custom-format dump and read it back:

```sh
kubectl -n harbor-deps exec deploy/postgres -- pg_dump -U harbor -d registry -Fc -f /backup/registry.dump
kubectl -n harbor-deps exec deploy/postgres -- pg_restore --list /backup/registry.dump | grep 'TABLE DATA' | head -3
```

The list shows tables with data. Save the installed values too, since the upgrade must start from them:

```sh
helm -n harbor get values harbor -o yaml > harbor-values.yaml
```

## Take the backup first

The order matters: the dump must be older than the upgrade. A dump taken after the upgrade holds the new schema and is no way back. Pushes that happen between the dump and the upgrade are lost on a restore, so on a busy Harbor you switch on read-only mode while you work, which refuses pushes and deletions but allows pulls.

You now know why Harbor needs a backup instead of a rollback, and you hold a dump and the installed values. The next part runs the upgrade and proves the result.

## Common pitfalls

> [!WARNING]
> - **Planning to use `helm rollback`.** The schema cannot be downgraded.
> - **Dumping after the upgrade.** The dump holds the new schema.
> - **Taking the dump in plain SQL.** Use `-Fc` so that you can read it.
> - **Forgetting the pushes between the dump and the upgrade.** Use read-only mode on a busy Harbor.
