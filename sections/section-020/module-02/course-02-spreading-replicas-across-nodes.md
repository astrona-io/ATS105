# Spreading Replicas Across Nodes

A budget limits how many pods go away at once. It does not stop the scheduler from putting both `registry` pods on the same node. When that node fails, both pods go, and the budget never had a say. This part shows the two ways to tell the scheduler to keep replicas apart and how the chart passes the settings on.

## Where the settings live

Every Harbor component with replicas has the values `affinity`, `nodeSelector`, `tolerations` and `topologySpreadConstraints`. They map to the same fields of the pod spec in the Deployment. By default all four are empty, so the scheduler places pods wherever there is room.

There are two tools to keep replicas apart. Pod anti-affinity says that a pod should not run on a node that already runs a pod with certain labels. A topology spread constraint says that the pods of a group should be spread evenly across the values of a node label, such as the host name or the zone, with a maximum difference called `maxSkew`.

## The topology spread constraint

A constraint has three important fields. `topologyKey` names the node label that defines a domain; `kubernetes.io/hostname` makes every node a domain. `maxSkew` is the largest allowed difference in the number of matching pods between two domains. `whenUnsatisfiable` says what to do when the rule cannot be met: `DoNotSchedule` leaves the pod pending, and `ScheduleAnyway` places it and only prefers a balanced result.

The chart helps here. For each constraint in the values, it adds the `labelSelector` of the component's own pods. You write only the three fields. These are the lines to add inside the existing `core:` and `registry:` blocks of your values file:

```yaml
core:
  topologySpreadConstraints:
    - maxSkew: 1
      topologyKey: kubernetes.io/hostname
      whenUnsatisfiable: ScheduleAnyway
registry:
  topologySpreadConstraints:
    - maxSkew: 1
      topologyKey: kubernetes.io/hostname
      whenUnsatisfiable: ScheduleAnyway
```

Use `DoNotSchedule` when you want a hard guarantee and have enough nodes. With fewer nodes than replicas, it leaves the extra pods pending. `ScheduleAnyway` is the safer first step, because Harbor starts even on a small cluster.

<!-- astrona:playground:renew -->

Merge the fragment into the installed values. Take care not to create a second `core:` key; edit the existing block. Then upgrade and look at the result:

```sh
helm -n harbor get values harbor -o yaml > harbor-values.yaml
helm upgrade harbor harbor/harbor --version 1.19.4 --namespace harbor \
  --values harbor-values.yaml --wait --timeout 20m
kubectl -n harbor get deployment harbor-core -o jsonpath='{.spec.template.spec.topologySpreadConstraints}' | jq
```

The output shows your three fields and the `labelSelector` that the chart added, with the component labels of `core`. A duplicate `core:` key in YAML does not give an error in Helm: the last one wins and the other is silently dropped. Always check the Deployment, not the file.

## Check where the pods run

List the node of each pod:

```sh
kubectl -n harbor get pods -o wide -l component=core
```

On the playground's single node, both pods show the same node name. On a cluster with several nodes and `kubernetes.io/hostname`, they show different names. A pod that cannot be placed stays in `Pending`; `kubectl describe pod` names the failed constraint in the events.

You now know how to keep replicas apart, how to choose between `DoNotSchedule` and `ScheduleAnyway`, and that the chart adds the selector. Together with the budgets, Harbor now survives both a drain and a failed node. The graded lab asks you to combine them.

## Common pitfalls

> [!WARNING]
> - **Writing `labelSelector` yourself.** The chart adds it; yours can conflict.
> - **Using `DoNotSchedule` on a small cluster.** Replicas stay pending.
> - **Creating a second `core:` key in the values.** Only the last block counts.
> - **Spreading only `core`.** `registry`, `portal` and `jobservice` need it too.
> - **Reading `Running` as spread.** Check the node column.

## Your mission: Spread And Protect Harbor's Replicas

You can now enable budgets and spread constraints and read their effect. The graded lab gives you a Harbor with two replicas of each component but no budgets and no spread rules, and asks you to add both without breaking it.

The lab runs in its own cluster, so first pause your playground. Nothing in it is lost:

```sh
astrona stop ats-105-playground-020-02
```

Then start the lab:

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS105.git -c sections/section-020/module-02/labs/lab-01
```

The task is on the next page. Solve it on your own first. When you think you are done, send it for grading:

```sh
astrona submit -c sections/section-020/module-02/labs/lab-01
```

When the lab is done, remove it and start your playground again:

```sh
astrona destroy ats-105-lab-020-02
astrona start ats-105-playground-020-02
```
