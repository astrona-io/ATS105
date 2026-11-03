# Solution: Upgrade Harbor In Place After A Backup

Work the task yourself first. Running `astrona submit -c sections/section-040/module-02/labs/lab-01` after a step tells you which checks pass, without telling you what is left.

The grader checks five things: a valid dump that is older than the upgraded pods, chart 1.19.4, the unchanged database host, read-only mode off, and a working pull.

## Step 1: Back up first

```sh
kubectl -n harbor-deps exec deploy/postgres -- pg_dump -U harbor -d registry -Fc -f /backup/registry.dump
kubectl -n harbor-deps exec deploy/postgres -- pg_restore --list /backup/registry.dump | grep 'TABLE DATA' | head -3
```

The second command lists tables with data, which proves the archive.

## Step 2: Save the installed values

```sh
helm -n harbor get values harbor -o yaml > harbor-values.yaml
```

Do not edit the file. The upgrade keeps every value.

## Step 3: Upgrade

Apply it:

```sh
helm upgrade harbor harbor/harbor --version 1.19.4 --namespace harbor \
  --values harbor-values.yaml --wait --timeout 20m
```

Then check the result:

```sh
helm -n harbor list
ws() { kubectl -n workstation exec -i deploy/workstation -- "$@"; }
ws curl -s https://harbor.localtest.me:8443/api/v2.0/health | ws jq -r '.status'
```

The chart is `harbor-1.19.4`, the app version is `2.15.4` and the status is `healthy`. Then submit:

```sh
astrona submit -c sections/section-040/module-02/labs/lab-01
```

## Why the obvious shortcuts are wrong

| Shortcut | What happens |
| --- | --- |
| Dump after the upgrade | The dump holds the new schema, and the grader sees it is newer than the pods |
| Upgrade with a file that holds only a few values | The external services and the certificate settings are dropped |
| `pg_dump` without `-Fc` | The grader cannot read the archive |
| Pointing the upgrade at `postgres-new` | That is a database move, which this task does not ask for |

## Common mistakes

- Upgrading first and planning to take the backup after the check.
- Using `--reuse-values` together with a new chart without reading what the new chart adds.
