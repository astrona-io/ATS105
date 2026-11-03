# Upgrading And Watching The Migration

The upgrade itself is one command. What matters is starting from the right values and checking, afterwards, that the schema moved and that Harbor works. This part runs the upgrade and collects three proofs.

## Record the schema version first

Harbor keeps the version of its schema in the table `schema_migrations`. Read it before the upgrade so that you can compare:

<!-- astrona:playground:renew -->

```sh
kubectl -n harbor-deps exec deploy/postgres -- psql -U harbor -d registry -tAc "select version, dirty from schema_migrations"
```

The command prints one row with the version number and `f` for `dirty`. A dirty value of `t` would mean that a migration stopped halfway.

## Upgrade with the installed values

A `helm upgrade` with a values file replaces the values you passed before. Use the file you saved in the previous part, which holds all of them. Apply it:

```sh
helm upgrade harbor harbor/harbor --version 1.19.4 --namespace harbor \
  --values harbor-values.yaml --wait --timeout 20m
```

The command waits until the Deployments are ready. `core` runs the migration when it starts, and its readiness probe passes only after the migration is done.

## Collect the proofs

The first proof is the release. The second is the migration table, read again. The third is a pull:

```sh
helm -n harbor list
kubectl -n harbor-deps exec deploy/postgres -- psql -U harbor -d registry -tAc "select version, dirty from schema_migrations"
ws() { kubectl -n workstation exec -i deploy/workstation -- "$@"; }
ws regctl registry login harbor.localtest.me:8443 -u admin -p Harbor12345
ws rm -rf /tmp/pull
ws regctl image copy harbor.localtest.me:8443/inventory/podinfo:6.15.0 ocidir:///tmp/pull:6.15.0 && echo "pull ok"
```

The release shows `harbor-1.19.4` and `2.15.4`. The version in the migration table is the same or higher than before, and `dirty` is still `f`. A patch release does not always change the schema, so an unchanged version is not an error. The pull prints `pull ok`. If `core` does not become ready, read its log with `kubectl -n harbor logs deployment/harbor-core` and look for lines about the migration.

You now know the whole sequence: read the chart difference, back up, upgrade with the installed values, and prove the result with the release, the migration table and a pull.

## Common pitfalls

> [!WARNING]
> - **Upgrading with a file that holds only the new values.** The external services and the certificate settings are dropped.
> - **Reading `--wait` as proof.** Check the migration table and pull an image.
> - **Ignoring `dirty = t`.** A stopped migration needs a restore, not another upgrade.
> - **Upgrading during peak push traffic.** Use read-only mode.

## Your mission: Upgrade Harbor In Place After A Backup

You can now plan an upgrade, take the backup and prove the result. The graded lab gives you Harbor 2.15.2 and asks for a fresh backup followed by an in-place upgrade to 2.15.4.

The lab runs in its own cluster, so first pause your playground. Nothing in it is lost:

```sh
astrona stop ats-105-playground-040-02
```

Then start the lab:

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS105.git -c sections/section-040/module-02/labs/lab-01
```

The task is on the next page. Solve it on your own first. When you think you are done, send it for grading:

```sh
astrona submit -c sections/section-040/module-02/labs/lab-01
```

When the lab is done, remove it and start your playground again:

```sh
astrona destroy ats-105-lab-040-02
astrona start ats-105-playground-040-02
```
