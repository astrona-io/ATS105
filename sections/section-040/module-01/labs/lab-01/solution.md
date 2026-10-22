# Solution: Upgrade Harbor And Move Its Database

Work the task yourself first. Running `astrona submit -c sections/section-040/module-01/labs/lab-01` after a step tells you which checks pass, without telling you what is left.

The grader checks four things: the chart and app version, the new database host with the project `inventory` on `postgres-new`, read-only mode off, and a complete pull of `inventory/podinfo:6.15.0`.

## Step 1: Helpers and the starting point

```sh
ws() { kubectl -n workstation exec -i deploy/workstation -- "$@"; }
harbor_api() {
  if [ -n "${3:-}" ]; then
    ws curl -sS -u admin:Harbor12345 -X "$1" -H 'Content-Type: application/json' \
      --data "$3" "https://harbor.localtest.me:8443/api/v2.0$2"
  else
    ws curl -sS -u admin:Harbor12345 -X "$1" "https://harbor.localtest.me:8443/api/v2.0$2"
  fi
}
helm -n harbor list
harbor_api GET /systeminfo | ws jq -r '.harbor_version'
```

The release runs `harbor-1.19.2`, and Harbor reports a version starting with `v2.15.2`.

## Step 2: Open the read-only window and copy the database

```sh
harbor_api PUT /configurations '{"read_only":true}'
kubectl -n harbor-deps exec deploy/postgres -- pg_dump -U harbor -d registry -Fc -f /backup/registry.dump
kubectl -n harbor-deps exec deploy/postgres -- cat /backup/registry.dump \
  | kubectl -n harbor-deps exec -i deploy/postgres-new -- sh -c 'cat > /backup/registry.dump'
kubectl -n harbor-deps exec deploy/postgres-new -- pg_restore -U harbor -d registry --clean --if-exists /backup/registry.dump
kubectl -n harbor-deps exec deploy/postgres-new -- psql -U harbor -d registry -tAc 'select name from project'
```

The new server lists `library` and `inventory`. The dump on `postgres` is also your backup before the upgrade.

## Step 3: Upgrade onto the new server

Start from the installed values, change only the host, and upgrade to 1.19.4:

```sh
helm -n harbor get values harbor -o yaml > harbor-values.yaml
sed -i.bak 's/host: postgres.harbor-deps.svc.cluster.local/host: postgres-new.harbor-deps.svc.cluster.local/' harbor-values.yaml
grep -n 'host:' harbor-values.yaml
helm upgrade harbor harbor/harbor --version 1.19.4 --namespace harbor \
  --values harbor-values.yaml --wait --timeout 20m
```

## Step 4: Check, then close the window

```sh
helm -n harbor list
ws curl -s https://harbor.localtest.me:8443/api/v2.0/health | ws jq -r '.status'
ws regctl registry login harbor.localtest.me:8443 -u admin -p Harbor12345
ws rm -rf /tmp/pull
ws regctl image copy harbor.localtest.me:8443/inventory/podinfo:6.15.0 ocidir:///tmp/pull:6.15.0 && echo "pull ok"
harbor_api PUT /configurations '{"read_only":false}'
harbor_api GET /configurations | ws jq -r '.read_only.value'
```

Helm shows `harbor-1.19.4` and `2.15.4`, Harbor is `healthy`, the pull prints `pull ok`, and read-only mode is `false`. The `read_only` setting is stored in the database, so it was copied with the dump: that is why the window stays open on the new server until you close it. Then submit:

```sh
astrona submit -c sections/section-040/module-01/labs/lab-01
```

## Why the obvious shortcuts are wrong

| Shortcut | What happens |
| --- | --- |
| Copy without read-only mode | A push during the copy exists only on the old server |
| Point Harbor at the empty `postgres-new` without a restore | Harbor starts fresh; the project `inventory` is gone and the grader refuses it |
| Leave read-only mode on | Every push fails; the grader refuses it |
| Upgrade with a new values file | The certificate and Secrets fall back to chart defaults |

## Common mistakes

- Running `pg_restore` before the dump is in the `postgres-new` pod.
- Closing the read-only window before checking Harbor on the new server.
