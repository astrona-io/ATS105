# Keep Harbor Replicas Available During Disruptions

Two replicas of `core` do not protect you if a node drain removes both at the same time, or if both run on the same node and that node fails. Replicas only help when Kubernetes places them apart, refuses to remove too many at once, and replaces them one by one. These rules are set in the chart's values, and the chart sets none of them by default.

Keep one sentence in mind: **a replica count states how many pods you want; a budget and a spread rule state how many of them may be gone at the same moment.** This module covers the PodDisruptionBudget, pod placement, rolling updates with probes and resource requests, and the connection limits that grow with the number of replicas.

The module has four parts. **Disruptions And PodDisruptionBudgets** explains the budget objects and the chart values that create them. **Spreading Replicas Across Nodes** covers affinity and topology spread constraints; a graded lab follows it. **Rolling Updates, Probes And Resource Requests** explains how a Deployment replaces pods safely. **Connection Budgets And Redis Failover** shows how replicas multiply database connections and how Harbor uses Redis Sentinel.

## Learning objectives

After this module you can:

- Explain the difference between a voluntary and an involuntary disruption.
- Enable a PodDisruptionBudget for each Harbor component and read how many disruptions it allows.
- Spread replicas across nodes with a topology spread constraint and say what `whenUnsatisfiable` changes.
- Describe how a rolling update uses the readiness probe, and why requests for resources matter.
- Calculate the number of database connections that Harbor can open and compare it with the server limit.
- Name the Redis modes Harbor supports and the value that selects Sentinel.

## Before you start

You need Kubernetes basics (Deployments, labels, nodes, `kubectl drain`) and the scaling of Harbor from the previous steps of the domain: `portal`, `core`, `jobservice` and `registry` can run more than one replica when the state is shared.

Your playground is a single-node `kind` cluster. **Harbor 2.15.4** runs there as the Helm release `harbor` in the namespace `harbor`, installed with chart 1.19.4 on the external PostgreSQL, Redis and S3 bucket in the namespace `harbor-deps`. Each of `portal`, `core`, `jobservice` and `registry` runs **two** replicas. Harbor answers at `https://harbor.localtest.me:8443`, and the project `inventory` holds `inventory/podinfo:6.15.0`. The `workstation` pod in the namespace `workstation` holds `regctl`, `curl` and `jq`. The administrator is `admin` with the password `Harbor12345`; these are lab-only credentials. Because the cluster has one node, placement rules show in the Deployment, but you cannot see replicas land on different nodes.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->
