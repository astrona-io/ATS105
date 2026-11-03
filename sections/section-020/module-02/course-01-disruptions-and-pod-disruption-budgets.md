# Disruptions And PodDisruptionBudgets

An administrator drains a node for a kernel update. Kubernetes evicts every pod on it. If both `core` pods run there, Harbor is down until new pods start elsewhere. Kubernetes can prevent this, but only when it is told how many pods of an application must stay. This part explains the kinds of disruption and the object that sets the limit.

## Two kinds of disruption

A disruption is the loss of a running pod. An involuntary disruption is one you did not ask for: a node crashes, the hardware fails or the kernel runs out of memory. A voluntary disruption is one a person or a controller asks for: a node drain, a cluster upgrade, an autoscaler removing a node, or a `kubectl delete pod`.

A PodDisruptionBudget (PDB) limits only voluntary disruptions that use the Eviction API, such as `kubectl drain`. It cannot stop a node from crashing, and a plain `kubectl delete pod` does not ask the budget. The PDB tells the Eviction API how many pods of the selected group must stay available, or how many may be unavailable.

## What the chart creates

Each of `portal`, `core`, `jobservice` and `registry` has a `podDisruptionBudget` block in the chart's values. The default is `enabled: false` with `minAvailable: 1`. The chart renders the object only when two conditions are true: the block is enabled and the component has more than one replica. With one replica a budget of `minAvailable: 1` would block every drain forever, so the chart does not create it.

Check the playground, where all four components have two replicas but nobody enabled the budget:

<!-- astrona:playground:renew -->

```sh
kubectl -n harbor get deployments
kubectl -n harbor get poddisruptionbudgets
```

The Deployments show `2/2` for the four components. The second command reports `No resources found in harbor namespace.`

## Enable the budgets

Read the installed values, add the blocks and upgrade. Save the current values first:

```sh
helm -n harbor get values harbor -o yaml > harbor-values.yaml
```

Add the budget to each component. The file already has a block for each of them, so add the `podDisruptionBudget` lines inside the existing blocks. For `core` the result looks like this:

```yaml
core:
  replicas: 2
  podDisruptionBudget:
    enabled: true
    minAvailable: 1
```

Do the same for `portal`, `jobservice` and `registry`. Then upgrade:

```sh
helm upgrade harbor harbor/harbor --version 1.19.4 --namespace harbor \
  --values harbor-values.yaml --wait --timeout 20m
```

## Read how many disruptions are allowed

Check the result:

```sh
kubectl -n harbor get poddisruptionbudgets
```

The output has four budgets, with the column `ALLOWED DISRUPTIONS` set to `1` for each one. With two replicas and `minAvailable: 1`, Kubernetes may evict one pod, and it refuses the second eviction while the first pod is gone. This number is the one to watch: a budget with `ALLOWED DISRUPTIONS` of `0` blocks every drain.

That is the common mistake. A budget of `minAvailable: 2` with two replicas allows nothing. A node drain then waits forever, and the administrator has to remove the budget by hand. Use `minAvailable: 1` for two replicas. The alternative `maxUnavailable: 1` keeps working when you scale up, but the chart default is `minAvailable: 1`, so setting `maxUnavailable` alone renders both fields and Kubernetes rejects the object. To use `maxUnavailable`, also set `minAvailable: null` in the values.

You now know what a PDB protects, how the chart decides to create it, and how to read its allowance. A budget limits how many pods go at the same moment, but it does not decide where the pods run. That is the next topic.

## Common pitfalls

> [!WARNING]
> - **Expecting the chart to create budgets.** The default is `enabled: false`.
> - **Enabling a budget on one replica.** The chart does not render it, and it would block drains.
> - **Setting `minAvailable` equal to the replicas.** `ALLOWED DISRUPTIONS` is `0` and drains hang.
> - **Setting `maxUnavailable` without `minAvailable: null`.** The chart default keeps `minAvailable`, and Kubernetes rejects the object with both.
> - **Thinking a PDB prevents a crash.** It limits only evictions.
