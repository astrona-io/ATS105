# Run Harbor With High Availability

Restart the single `harbor-registry` pod of a busy Harbor and count the failed pulls in your deployment pipelines. For the seconds or minutes the pod needs to come back, every push and every pull fails. A registry sits in the path of every deployment, so its downtime is everybody's downtime.

High availability (HA) means that losing one pod of a component does not stop the service. Keep one sentence in mind: **a component can only run twice if its state lives somewhere else.** Once Harbor's records are in an external PostgreSQL, its queues in an external Redis and its images in a shared bucket, `core`, `portal`, `jobservice` and `registry` are just code, and you can run as many copies as you like.

The module has two parts. **What High Availability Needs** lists what must be outside the chart, which state each component shares, and why the Harbor Operator is not part of the answer. **Scaling The Components And Proving It** scales every component to two replicas and proves the result by deleting pods while pushing and pulling. A graded lab follows the second part.

## Learning objectives

After this module you can:

- List what the Harbor high-availability guide requires outside the chart.
- Explain which state `core`, `jobservice` and `registry` share, and where it lives.
- Explain why registry replicas need shared storage, and what goes wrong without it.
- Explain why `jobservice` replicas need their logs in the database.
- Scale `portal`, `core`, `jobservice` and `registry` with the chart's `replicas` values.
- Prove high availability by deleting pods while pushing and pulling.
- Explain the state of the Harbor Operator project.

## Before you start

You need to know what each Harbor component does and how the chart points Harbor at an external PostgreSQL, Redis and S3 store. You should be comfortable with `helm upgrade` with a values file and with Deployments and their replicas.

Your playground is a single-node `kind` cluster with **Harbor 2.15.4** (chart 1.19.4) in the namespace `harbor`, already on the external services in the namespace `harbor-deps`: PostgreSQL 15.19, Redis 7.4.11 and the S3 bucket `harbor`. Each Harbor component runs one replica. The project `inventory` holds `inventory/podinfo:6.15.0`. The `workstation` pod holds `regctl`, `curl` and `jq` and trusts Harbor's certificate. The administrator is `admin` with the password `Harbor12345` (lab-only).

The playground runs on one node, so it can show replicas and shared state, but not the loss of a whole node.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->
