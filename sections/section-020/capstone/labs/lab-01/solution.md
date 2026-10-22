# Solution: Make A Scaled Harbor Consistent

Work the task yourself first. Running `astrona submit -c sections/section-020/capstone/labs/lab-01` after a step tells you which checks pass, without telling you what is left.

The grader checks four things: at least 2 ready replicas of the four components, S3 storage, the `database` job logger, and 20 successful reads in a row of a freshly pushed image, with its data in the bucket `harbor`.

## Step 1: Reproduce the failure

```sh
ws() { kubectl -n workstation exec -i deploy/workstation -- "$@"; }
ws regctl registry login harbor.localtest.me:8443 -u admin -p Harbor12345
ws regctl image copy ghcr.io/stefanprodan/podinfo:6.15.0 harbor.localtest.me:8443/inventory/podinfo:check
for attempt in 1 2 3 4 5 6; do
  ws regctl manifest head harbor.localtest.me:8443/inventory/podinfo:check >/dev/null 2>&1 && echo ok || echo failed
done
```

Some reads print `ok` and some `failed`, in no fixed order. The Service sends each request to one of the two registry pods, and only one of them has the data.

## Step 2: Find the three faults

```sh
kubectl -n harbor get deployments
helm -n harbor get values harbor -o yaml > harbor-values.yaml
grep -n -A3 'persistence:\|jobservice:\|core:\|registry:' harbor-values.yaml
```

Three things stand out:

- `persistence` has no `imageChartStorage` block, so the registry uses `filesystem`, and with `persistence.enabled: false` each registry pod has its own `emptyDir`. Two replicas, two separate stores: that is the random failure.
- `core` runs only one replica.
- `jobservice.jobLoggers` is `file`, so each `jobservice` replica keeps its own logs.

## Step 3: Fix the values

Edit `harbor-values.yaml`. Add the S3 storage under `persistence`:

```yaml
persistence:
  enabled: false
  imageChartStorage:
    disableredirect: true
    type: s3
    s3:
      existingSecret: harbor-s3
      region: us-east-1
      bucket: harbor
      regionendpoint: http://s3.harbor-deps.svc.cluster.local:9000
      v4auth: true
```

Set `core.replicas` to `2` and `jobservice.jobLoggers` to `database`:

```yaml
jobservice:
  replicas: 2
  jobLoggers:
    - database
core:
  replicas: 2
```

Keep `portal` and `registry` at `2`, and every other line as it is.

## Step 4: Upgrade and prove it

```sh
helm upgrade harbor harbor/harbor --version 1.19.4 --namespace harbor \
  --values harbor-values.yaml --wait --timeout 20m
ws regctl image copy ghcr.io/stefanprodan/podinfo:6.15.0 harbor.localtest.me:8443/inventory/podinfo:check2
for attempt in $(seq 1 20); do
  ws regctl manifest head harbor.localtest.me:8443/inventory/podinfo:check2 >/dev/null 2>&1 && echo ok || echo failed
done
kubectl -n harbor-deps exec deploy/s3-client -- aws s3 ls s3://harbor/docker/registry/v2/repositories/inventory/
```

All 20 reads print `ok`, and the bucket holds `podinfo/`. The old tags pushed before the fix point at layers the new storage never had; the task allows that. Then submit:

```sh
astrona submit -c sections/section-020/capstone/labs/lab-01
```

## Why the obvious shortcuts are wrong

| Shortcut | What happens |
| --- | --- |
| Scale `registry` to 1 | Reads become consistent, but the registry is a single point of failure again; the grader refuses it |
| Add session affinity to the Service | A push and a later pull from another client still reach different pods |
| Copy files between the two `emptyDir` volumes | Breaks again with the next push or the next restarted pod |

## Common mistakes

- Trusting the health endpoint. It checks that each component answers, not that the replicas share data.
- Testing with an image pushed before the fix, whose layers live in one pod only.
