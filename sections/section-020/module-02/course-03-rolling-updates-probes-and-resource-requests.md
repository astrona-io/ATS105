# Rolling Updates, Probes And Resource Requests

A rolling update replaces pods one at a time. The Deployment controller starts a new pod, waits until it reports ready, and only then stops an old pod. This works only when the readiness probe tells the truth and the scheduler knows how much room each pod needs. This part explains how the pieces fit, and what to set in the chart.

## How a rolling update proceeds

The chart sets `updateStrategy.type` to `RollingUpdate` for the Deployments it creates. A rolling update has two limits with Kubernetes defaults of 25 percent: `maxSurge`, the number of extra pods that may run during the update, and `maxUnavailable`, the number of pods that may be missing. Kubernetes rounds `maxSurge` up and `maxUnavailable` down. With two replicas that means one extra pod and no missing pod: the Deployment never has fewer than two ready pods.

Read the strategy of `core` in the playground:

<!-- astrona:playground:renew -->

```sh
kubectl -n harbor get deployment harbor-core -o jsonpath='{.spec.strategy}{"\n"}'
```

The answer shows `RollingUpdate` and no explicit limits, which means the 25 percent defaults apply.

## Probes decide when a pod counts

A readiness probe tells Kubernetes whether a pod may receive requests. A pod that is not ready is removed from the Service endpoints, and a rolling update waits for it. A liveness probe tells Kubernetes whether to restart the container. The chart sets both for each component; for example `jobservice` waits 20 seconds before the first readiness check and 300 seconds before the first liveness check, so a slow start does not cause a restart loop.

The rule for a rolling update is simple: the new pod must pass its readiness probe before an old pod stops. If a new pod never becomes ready, for example because it cannot reach the database, the update stops with the old pods still serving. That is the desired behaviour, and it is why a bad change shows as a stuck rollout and not as an outage. Prove that Harbor stays reachable during a restart of `core`. Open a second terminal and run a loop that pulls an image once per second:

```sh
ws() { kubectl -n workstation exec -i deploy/workstation -- "$@"; }
ws regctl registry login harbor.localtest.me:8443 -u admin -p Harbor12345
for attempt in $(seq 1 30); do
  ws rm -rf /tmp/pull
  ws regctl image copy harbor.localtest.me:8443/inventory/podinfo:6.15.0 ocidir:///tmp/pull:6.15.0 >/dev/null 2>&1 && echo "ok" || echo "FAILED"
  sleep 1
done
```

In the first terminal, restart `core` while the loop runs:

```sh
kubectl -n harbor rollout restart deployment/harbor-core
kubectl -n harbor rollout status deployment/harbor-core --timeout=300s
```

With two ready replicas, the loop prints `ok` for every attempt. A request that hits a pod at the moment it terminates can still fail on some clusters, so a client should retry; the lab-grade proof is that most attempts succeed and none runs for long without success.

## Resource requests

The chart leaves `resources` commented out for most components, so pods have no requests and no limits. The scheduler then assumes that each pod needs nothing, and places them on a node until the node runs out of memory. The pods start to be killed. Set requests for each component so that the scheduler can plan, and set a memory limit so that one component cannot take the memory of the others. A request is what the scheduler reserves; a limit is the most the container may use.

Add a block like this under `core` and the other components, with values that match your load:

```yaml
core:
  resources:
    requests:
      cpu: 200m
      memory: 256Mi
    limits:
      memory: 1Gi
```

You now know how a rolling update uses the readiness probe, why two replicas keep Harbor reachable, and why requests belong in the values. The last topic of the module is a limit that grows with the number of replicas: the connections to the database and the way Harbor reaches a highly available Redis.

## Common pitfalls

> [!WARNING]
> - **Treating `rollout status` as proof of availability.** Pull in a loop while it runs.
> - **Raising `maxUnavailable` to speed up an update.** You lose the guarantee of the second replica.
> - **Leaving `resources` empty.** Pods are scheduled blindly and killed under pressure.
> - **Setting a CPU limit tight to the request.** The container is throttled and slow probes fail.
> - **Shortening the liveness delay of `jobservice`.** A slow start then causes restarts.
