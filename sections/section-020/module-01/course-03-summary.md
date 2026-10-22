# Summary

A Harbor with one pod per component stops whenever one of those pods restarts. This module made every stateless component run twice and proved that the loss of a pod goes unnoticed.

## What you learned

The Harbor guide for high availability with Helm asks for four things outside the chart: a highly available PostgreSQL, a highly available Redis, shared storage for the registry (object storage or a `ReadWriteMany` volume), and a highly available ingress or load balancer. Harbor adds no clustering of its own. Its replicas never talk to each other; they meet only in the shared state.

Each component shares a different part of that state. `core` replicas share users, sessions and caches through PostgreSQL and Redis. `jobservice` replicas take jobs from one queue in Redis, and their logs belong in the database, or each replica keeps only its own. `registry` replicas must read the same layers, because the requests of one push can reach different replicas. On separate filesystems each replica holds only part of an image, and pulls fail at random while every pod looks healthy.

Scaling is one value per component: `portal.replicas`, `core.replicas`, `jobservice.replicas` and `registry.replicas`, set to 2 or more. The proof is not a `2/2` in `kubectl get deployments`, but requests that keep working while pods are deleted. The Harbor Operator, an older way to run Harbor on Kubernetes, is archived and has had no release since v1.3.0 in 2022, so the `harbor-helm` chart is the way to run Harbor.

The key facts to remember are these:

- A component can only run twice if its state lives outside its pods.
- Registry replicas need object storage or a `ReadWriteMany` volume; job logs need the `database` logger.
- Harbor is only as available as its PostgreSQL, its Redis and the proxy in front of it.
- Prove high availability by losing pods during pushes and pulls.

<!-- astrona:playground:destroy -->
