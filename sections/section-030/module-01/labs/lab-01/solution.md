# Solution: Back Up Harbor And Restore It After A Disaster

Work the task yourself first. Running `astrona submit -c sections/section-030/module-01/labs/lab-01` after a step tells you which checks pass, without telling you what is left.

The grader checks four things: the database `registry` was dropped and recreated and the release installed again, `inventory/podinfo:6.15.0` pulls with its original digest, Harbor uses the Secret `harbor-secretkey`, and Harbor is healthy.

## Step 1: Record the digest

```sh
ws() { kubectl -n workstation exec -i deploy/workstation -- "$@"; }
ws regctl registry login harbor.localtest.me:8443 -u admin -p Harbor12345
ORIGINAL_DIGEST="$(ws regctl image digest harbor.localtest.me:8443/inventory/podinfo:6.15.0)"
echo "$ORIGINAL_DIGEST"
```

## Step 2: Back up all five pieces

```sh
kubectl -n harbor-deps exec deploy/postgres -- pg_dump -U harbor -d registry -Fc -f /backup/registry.dump
kubectl -n harbor-deps exec deploy/s3-client -- aws s3 sync s3://harbor s3://harbor-backup
kubectl -n harbor get secret harbor-tls harbor-secretkey -o yaml > harbor-secrets-backup.yaml
helm -n harbor get values harbor -o yaml > harbor-values-backup.yaml
```

Check each one before the disaster: `/backup/registry.dump` exists in the `postgres` pod, `harbor-backup` holds `docker/registry/v2/`, and both files are on your machine.

## Step 3: The disaster

Run the three commands from the task exactly as written.

## Step 4: Restore the data, then Harbor

```sh
kubectl -n harbor-deps exec deploy/postgres -- createdb -U harbor --maintenance-db=postgres registry
kubectl -n harbor-deps exec deploy/postgres -- pg_restore -U harbor -d registry /backup/registry.dump
kubectl -n harbor-deps exec deploy/s3-client -- aws s3 sync s3://harbor-backup s3://harbor
kubectl apply -f harbor-secrets-backup.yaml
helm install harbor harbor/harbor --version 1.19.4 --namespace harbor \
  --values harbor-values-backup.yaml --wait --timeout 20m
```

The order matters: the database and the storage come back before Harbor starts, so `core` finds its tables instead of creating new ones.

## Step 5: Prove it

```sh
RESTORED_DIGEST="$(ws regctl image digest harbor.localtest.me:8443/inventory/podinfo:6.15.0)"
[ "$RESTORED_DIGEST" = "$ORIGINAL_DIGEST" ] && echo "same digest"
ws rm -rf /tmp/pull
ws regctl image copy harbor.localtest.me:8443/inventory/podinfo:6.15.0 ocidir:///tmp/pull:6.15.0 && echo "pull ok"
ws curl -s https://harbor.localtest.me:8443/api/v2.0/health | ws jq -r '.status'
```

You should see `same digest`, `pull ok` and `healthy`. Then submit:

```sh
astrona submit -c sections/section-030/module-01/labs/lab-01
```

## Why the obvious shortcuts are wrong

| Shortcut | What happens |
| --- | --- |
| Skip the disaster | The grader sees the original database and refuses it |
| Install Harbor before `pg_restore` | Harbor creates its own tables and the restore collides with them |
| Restore the database but not the bucket | The digest matches, but the full pull fails |
| Install without `existingSecretSecretKey` | Harbor runs with the chart's default key and cannot decrypt stored passwords |

## Common mistakes

- Forgetting `--maintenance-db=postgres` on `dropdb` and `createdb`: they cannot connect to the database they drop or create.
- Losing the shell variable `ORIGINAL_DIGEST` in a new terminal. Write the digest down.
