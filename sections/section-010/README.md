# Section 010: Harbor On External Services

A fresh Harbor installation keeps everything in its own pods. The chart starts a PostgreSQL database, a Redis server and a registry that writes image layers to a local directory. That is fine for a test, but every production topic after it depends on moving that data out: replicas can only share state that lives outside them, and a backup is only as good as the services it copies.

This section moves Harbor's data to services built for it. You will learn which component keeps which data, then point the `harbor-helm` chart at an external PostgreSQL, an external Redis and S3-compatible object storage, with every password read from a Kubernetes Secret.

**Topic covered:** Running Harbor on external services

## What you will learn

- Which Harbor component stores what: PostgreSQL, Redis, the registry storage and the job logs.
- The Helm values for an external PostgreSQL: `database.type`, `database.external.*` and `existingSecret`.
- The Helm values for an external Redis, including Sentinel, and what Harbor does not support.
- The Helm values for S3-compatible storage under `persistence.imageChartStorage`.
- Why job logs belong in the database once Harbor stops keeping files in its pods.
- How to prove the move: tables in PostgreSQL, objects in the bucket, a push and a pull that work.

## The learning path

The module has a landing page, three short parts, a graded lab right after the part it tests, and a summary. The landing page starts the module's playground.

### 1. Run Harbor On External Services

The playground holds Harbor on its internal services and, next to it, an empty PostgreSQL, a Redis server and an S3 store in the namespace `harbor-deps`.

1. What Harbor Keeps Where
2. External PostgreSQL And Redis
3. Object Storage For Images And Job Logs, followed by the lab **Move Harbor To External PostgreSQL, Redis And S3**
4. Summary

## Section capstone: Repair A Harbor That Cannot Reach Its Services

Someone moved Harbor to the external services and stopped halfway through the checks. Harbor does not become healthy, and three separate faults stand between it and its database, Redis and bucket. Work the capstone after the module lab.

Start the capstone:

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS105.git -c sections/section-010/capstone/labs/lab-01
```

When you think you are done, send it for grading:

```sh
astrona submit -c sections/section-010/capstone/labs/lab-01
```

When the capstone is done, remove it:

```sh
astrona destroy ats-105-capstone-010
```
