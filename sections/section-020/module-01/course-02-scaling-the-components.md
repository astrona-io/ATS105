# Scaling The Components And Proving It

A Harbor with its state outside its pods is ready to scale, but "ready" is a claim, not a proof. This part scales every stateless component to two replicas, then deletes pods while it keeps pushing and pulling. If the requests keep working, the replicas really share their state.

## The replica values

The chart has one `replicas` value per component. The Harbor high-availability guide names four of them:

| Value | Component |
| --- | --- |
| `portal.replicas` | The web user interface |
| `core.replicas` | The API server and token service |
| `jobservice.replicas` | The background job runner |
| `registry.replicas` | The registry, together with its `registryctl` sidecar |

The chart's `nginx` proxy has a `replicas` value too. In this course every request passes through it, so a real installation scales it as well, or replaces it with an ingress controller that is highly available on its own, as the guide asks.

Start from the values that are installed:

<!-- astrona:playground:renew -->

```sh
helm -n harbor get values harbor -o yaml > harbor-values.yaml
cat harbor-values.yaml
```

The file holds the TLS, URL, password and `secretKey` settings, the external `database` and `redis` blocks, the S3 storage under `persistence.imageChartStorage`, and `jobservice.jobLoggers` set to `database`.

## Scale to two replicas

Add the replica counts to the file you just saved. The `jobservice` block already exists, so add `replicas: 2` inside it; the other three are new top-level blocks. The end of `harbor-values.yaml` then looks like this:

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

Apply it:

```sh
helm upgrade harbor harbor/harbor --version 1.19.4 --namespace harbor \
  --values harbor-values.yaml --wait --timeout 20m
```

Then check the result:

```sh
kubectl -n harbor get deployments
kubectl -n harbor get pods -l component=registry -o wide
```

`harbor-portal`, `harbor-core`, `harbor-jobservice` and `harbor-registry` each show `2/2`. The chart labels its pods with `component`, so the second command lists the two registry pods. On a cluster with more than one node they would land on different nodes; the chart's `affinity` values let you require that.

## Prove it by losing pods

A test of high availability must break something. Define two helpers: `ws` runs a command in the `workstation` pod, and `pull_podinfo` downloads the whole image, every layer included, into a throwaway folder there.

```sh
ws() { kubectl -n workstation exec -i deploy/workstation -- "$@"; }
pull_podinfo() {
  ws rm -rf /tmp/pull
  ws regctl image copy harbor.localtest.me:8443/inventory/podinfo:6.15.0 ocidir:///tmp/pull:6.15.0 && echo "pull ok"
}
ws regctl registry login harbor.localtest.me:8443 -u admin -p Harbor12345
pull_podinfo
```

The pull prints `pull ok`. Now delete one `core` pod and one `registry` pod, without waiting, and pull again straight away:

```sh
kubectl -n harbor delete pod "$(kubectl -n harbor get pods -l component=core -o name | head -1 | cut -d/ -f2)" --wait=false
kubectl -n harbor delete pod "$(kubectl -n harbor get pods -l component=registry -o name | head -1 | cut -d/ -f2)" --wait=false
pull_podinfo
pull_podinfo
```

Both pulls print `pull ok`. The remaining `core` replica issued the token and the remaining `registry` replica served every layer from the shared bucket, while Kubernetes started replacements. Run `kubectl -n harbor get pods` a minute later and every Deployment is back at two ready pods.

Pushing is the harder test, because a push is many requests in a row. Push a new tag while you delete a registry pod in a second terminal, then pull it back: the push and the pull succeed, because every upload request writes to the same bucket, whichever replica it reaches. On a single replica, the same test fails for the seconds the new pod needs to start.

You now have a Harbor that survives the loss of any one pod: two replicas of every stateless component, sharing PostgreSQL, Redis and a bucket, and you proved it by deleting pods under load. What remains is to do it on a Harbor you did not prepare yourself.

## Common pitfalls

> [!WARNING]
> - **Testing high availability by reading `2/2`.** Ready pods do not prove shared state. Delete pods while you push and pull.
> - **Forgetting the proxy.** Every request passes through `nginx` or your ingress. One replica there is still a single point of failure.
> - **Waiting for the replacement pod before testing.** The test is whether requests work while a pod is missing, not after it is back.
> - **Scaling without the `database` job logger.** Jobs run, but their logs are split between pods.

## Your mission: Scale Harbor To Two Replicas Per Component

You can now scale Harbor's components and prove that requests survive the loss of a pod. The graded lab gives you a Harbor on external services with one replica each and job logs in files, and asks you to make it highly available.

The lab runs in its own cluster, so first pause your playground. Nothing in it is lost:

```sh
astrona stop ats-105-playground-020-01
```

Then start the lab:

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS105.git -c sections/section-020/module-01/labs/lab-01
```

The task is on the next page. Solve it on your own first. When you think you are done, send it for grading:

```sh
astrona submit -c sections/section-020/module-01/labs/lab-01
```

When the lab is done, remove it and start your playground again:

```sh
astrona destroy ats-105-lab-020-01
astrona start ats-105-playground-020-01
```
