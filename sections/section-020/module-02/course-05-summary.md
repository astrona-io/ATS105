# Summary

Replicas keep Harbor running only when Kubernetes also limits and places them. A voluntary disruption, such as a node drain, uses the Eviction API, and a PodDisruptionBudget tells that API how many pods must stay. The chart creates a budget for a component only when its `podDisruptionBudget.enabled` is true and the component has more than one replica. With two replicas, `minAvailable: 1` allows one eviction at a time. A budget that equals the replica count allows none and blocks every drain.

Placement is a separate setting. A topology spread constraint spreads the pods of a group across the values of a node label, such as the host name, with a maximum difference named `maxSkew`. `DoNotSchedule` leaves a pod pending when the rule cannot be met, and `ScheduleAnyway` places it. The chart adds the label selector of the component itself, so the values hold only the three fields. Placement shows in the node column of the pod list, not in the pod status.

A rolling update starts a new pod and waits for its readiness probe before it stops an old one. With two replicas and the default limits of 25 percent, the Deployment never has fewer than two ready pods. The chart sets no requests or limits by default, so the scheduler places pods without knowing how much room they need.

Every replica of `core` has its own pool of database connections, and the pools add up. The ceilings in the chart, `maxIdleConns` and `maxOpenConns`, must be sized against the `max_connections` of the server, including the extra pod during an update. For Redis, the chart supports a single server and Sentinel through `sentinelMasterSet`, not Redis Cluster.

Key facts to remember:

- A budget is not created unless it is enabled and the replicas are above one.
- Check `ALLOWED DISRUPTIONS` after every change.
- Pull in a loop while a rollout runs to prove availability.
- Replicas multiply database connections.

<!-- astrona:playground:destroy -->
