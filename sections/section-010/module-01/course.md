# Run Harbor On External Services

Install Harbor with the `harbor-helm` chart and its defaults, and the chart starts its own PostgreSQL database, its own Redis server, and a registry that writes every image layer to a directory inside its pod. Delete those pods without persistent volumes and every project, user and image is gone. Scale the registry to two pods and each one sees only the layers that were pushed to it.

The fix is to keep Harbor's data in services built for it. Keep one sentence in mind: **Harbor's pods should hold no data that you cannot lose.** PostgreSQL holds Harbor's records, Redis holds its queues and caches, and object storage holds the images. Harbor's own pods then only run code.

This module moves an installed Harbor to those services. **What Harbor Keeps Where** maps each kind of data to the component that writes it, on a running Harbor. **External PostgreSQL And Redis** points the chart at an external database and Redis, with the password in a Kubernetes Secret. **Object Storage For Images And Job Logs** moves the registry's storage to an S3 bucket and the job logs to the database. A graded lab follows the third part.

## Learning objectives

After this module you can:

- Name the data that PostgreSQL, Redis, the registry storage and `jobservice` each hold.
- Find where a running Harbor keeps each kind of data, from its pods and ConfigMaps.
- Write the Helm values for an external PostgreSQL and an external Redis.
- Explain what Harbor supports for Redis: a single server or Sentinel, not Redis Cluster.
- Write the Helm values for S3-compatible object storage, with the keys read from a Secret.
- Explain why job logs go to the database when Harbor keeps no files in its pods.
- Prove a move with a push and a pull, Harbor's tables in PostgreSQL and the image data in the bucket.

## Before you start

You need Kubernetes basics (pods, Deployments, StatefulSets, Services, Secrets, `kubectl logs`) and you should have installed a chart with `helm install` and changed it with `helm upgrade`. You should know what an image tag and a digest are.

Your playground is a single-node `kind` cluster. **Harbor 2.15.4** runs there, installed with the `harbor-helm` chart 1.19.4 as the release `harbor` in the namespace `harbor`, still on its internal database, Redis and filesystem storage. It answers at `https://harbor.localtest.me:8443`. Next to it, the namespace `harbor-deps` holds the services Harbor will move to:

| Workload | What it is |
| --- | --- |
| `postgres` | PostgreSQL 15.19 with the empty database `registry` and the user `harbor` |
| `redis` | Redis 7.4.11 on port `6379`, without a password |
| `versitygw` (Service `s3`) | An S3-compatible object store on port `9000` with the empty bucket `harbor` |
| `s3-client` | A pod with the AWS command-line tool, already pointed at the store |

The namespace `harbor` also holds four Secrets prepared for you: `harbor-tls` (Harbor's certificate), `harbor-secretkey`, `harbor-external-db` and `harbor-s3`. The `workstation` pod in the namespace `workstation` holds `regctl`, `curl`, `jq` and the `harbor` command-line tool, and trusts Harbor's certificate. The administrator is `admin` with the password `Harbor12345`; these are lab-only credentials.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->
