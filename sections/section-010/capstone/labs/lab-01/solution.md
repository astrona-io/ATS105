# Solution: Repair A Harbor That Cannot Reach Its Services

Work the task yourself first. Running `astrona submit -c sections/section-010/capstone/labs/lab-01` after a step tells you which checks pass, without telling you what is left.

The grader checks four things: the Helm values point at the right services through Secrets, the Secret `harbor-database` has the key `password`, Harbor reports healthy, and a new image pushes, pulls and lands in the bucket `harbor`.

## Step 1: See which components fail

```sh
kubectl -n harbor get pods
kubectl -n harbor logs deploy/harbor-core --tail=30
```

`harbor-core` restarts, and its log shows it cannot connect to the database: the password it sends is empty or rejected. Other components that depend on `core` or on Redis fail with it, so fix the failures in the order of the log, not the order of the pod list.

## Step 2: The database password Secret

The chart reads the database password from the key `password` of the Secret named in `database.external.existingSecret`. Look at the keys the Secret really has:

```sh
kubectl -n harbor get secret harbor-database -o jsonpath='{.data}' | jq 'keys'
```

It has one key, `db-password`. The chart does not read that key, so Harbor gets no password. Recreate the Secret with the right key and the same value:

```sh
DB_PASSWORD="$(kubectl -n harbor get secret harbor-database -o jsonpath='{.data.db-password}' | base64 -d)"
kubectl -n harbor create secret generic harbor-database \
  --from-literal=password="$DB_PASSWORD" --dry-run=client -o yaml | kubectl apply -f -
```

## Step 3: Redis and the bucket in the values

Read the values the colleague used:

```sh
helm -n harbor get values harbor -o yaml > harbor-values.yaml
grep -n 'addr:\|bucket:' harbor-values.yaml
kubectl -n harbor-deps get service redis
kubectl -n harbor-deps exec deploy/s3-client -- aws s3 ls
```

The values say Redis is on port `6380`, but the Service `redis` listens on `6379`. And the values name the bucket `harbor-images`, which does not exist; the store only has `harbor`. Edit `harbor-values.yaml` so that `addr` is `redis.harbor-deps.svc.cluster.local:6379` and `bucket` is `harbor`. Leave everything else as it is.

## Step 4: Upgrade and restart

Apply it:

```sh
helm upgrade harbor harbor/harbor --version 1.19.4 --namespace harbor \
  --values harbor-values.yaml --wait --timeout 20m
```

The Secret changed after the pods started, and a pod reads a Secret's environment variables only when it starts. Restart the Deployments so every component reads the fixed Secret:

```sh
kubectl -n harbor rollout restart deployment
kubectl -n harbor rollout status deployment/harbor-core --timeout=600s
```

## Step 5: Prove it

```sh
ws() { kubectl -n workstation exec -i deploy/workstation -- "$@"; }
ws curl -s https://harbor.localtest.me:8443/api/v2.0/health | ws jq -r '.status'
ws curl -s -u admin:Harbor12345 -H 'Content-Type: application/json' \
  -d '{"project_name":"inventory","metadata":{"public":"false"}}' \
  https://harbor.localtest.me:8443/api/v2.0/projects
ws regctl registry login harbor.localtest.me:8443 -u admin -p Harbor12345
ws regctl image copy ghcr.io/stefanprodan/podinfo:6.15.0 harbor.localtest.me:8443/inventory/podinfo:6.15.0
kubectl -n harbor-deps exec deploy/s3-client -- aws s3 ls s3://harbor/docker/registry/v2/repositories/inventory/
```

Harbor is `healthy`, the copy succeeds, and the bucket `harbor` holds `podinfo/`. Then submit:

```sh
astrona submit -c sections/section-010/capstone/labs/lab-01
```

## Why the obvious shortcuts are wrong

| Shortcut | What happens |
| --- | --- |
| Write the password into `database.external.password` | Harbor works, but the password is in the release history; the grader refuses it |
| Create a bucket `harbor-images` | The task says to leave the store as it is, and the grader looks for the data in `harbor` |
| Point Harbor back at its internal database | Harbor gets healthy, but the move the team asked for is undone |

## Common mistakes

- Fixing the Secret but not restarting the pods, so they keep the empty password.
- Changing three things at once and not knowing which one mattered. Fix one, check the logs, then the next.
