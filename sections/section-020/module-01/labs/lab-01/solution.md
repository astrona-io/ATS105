# Solution: Scale Harbor To Two Replicas Per Component

Work the task yourself first. Running `astrona submit -c sections/section-020/module-01/labs/lab-01` after a step tells you which checks pass, without telling you what is left.

The grader checks four things: at least 2 ready replicas of `portal`, `core`, `jobservice` and `registry`, the `database` job logger, a healthy Harbor, and pushes and pulls that keep working while it deletes one `core` pod and one `registry` pod.

## Step 1: Start from the installed values

```sh
helm -n harbor get values harbor -o yaml > harbor-values.yaml
grep -n -A2 'jobservice:' harbor-values.yaml
kubectl -n harbor get deployments
```

The values have a `jobservice` block with `jobLoggers` set to `file`, and every Deployment shows `1/1`.

## Step 2: Add the replicas and the job logger

Edit `harbor-values.yaml`. Replace the `jobservice` block and add the three new blocks, so the end of the file reads:

```yaml
jobservice:
  replicas: 2
  jobLoggers:
    - database
portal:
  replicas: 2
core:
  replicas: 2
registry:
  replicas: 2
```

Keep every other line of the file as it is.

## Step 3: Upgrade

Apply it:

```sh
helm upgrade harbor harbor/harbor --version 1.19.4 --namespace harbor \
  --values harbor-values.yaml --wait --timeout 20m
```

Then check the result:

```sh
kubectl -n harbor get deployments
ws() { kubectl -n workstation exec -i deploy/workstation -- "$@"; }
ws curl -s https://harbor.localtest.me:8443/api/v2.0/health | ws jq -r '.status'
```

The four Deployments show `2/2`, and the status is `healthy`.

## Step 4: Prove it before the grader does

```sh
ws regctl registry login harbor.localtest.me:8443 -u admin -p Harbor12345
kubectl -n harbor delete pod "$(kubectl -n harbor get pods -l component=registry -o name | head -1 | cut -d/ -f2)" --wait=false
ws rm -rf /tmp/pull
ws regctl image copy harbor.localtest.me:8443/inventory/podinfo:6.15.0 ocidir:///tmp/pull:6.15.0 && echo "pull ok"
```

The pull prints `pull ok` while the deleted pod is still being replaced. Then submit:

```sh
astrona submit -c sections/section-020/module-01/labs/lab-01
```

## Why the obvious shortcuts are wrong

| Shortcut | What happens |
| --- | --- |
| `kubectl scale deployment --replicas=2` | Works until the next `helm upgrade`, which sets the chart's value again |
| Scale but keep `jobLoggers: [file]` | Each `jobservice` replica keeps its own logs, and the grader refuses it |
| Scale only `core` and `registry` | A `portal` or `jobservice` restart still stops part of Harbor |

## Common mistakes

- Upgrading with a file that holds only the replica blocks, which drops the external services and the certificate settings.
- Reading `2/2` as proof without deleting a pod.
