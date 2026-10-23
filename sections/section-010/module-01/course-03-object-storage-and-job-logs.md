# Object Storage For Images And Job Logs

The largest part of Harbor's data is the images themselves, and a directory in a pod is the worst place for them. A bucket in an object store survives any pod, any node and any number of registry replicas. This part moves the registry's storage to an S3-compatible bucket, moves the job logs into the database, and proves that a pushed image really lands in the bucket.

## Object storage for the registry

Object storage keeps data as objects in buckets, and clients reach it over an HTTP API. S3 is the API Amazon defined and most object stores copy. Harbor's registry is a fork of CNCF Distribution 2.8.3, and it has storage drivers for `filesystem`, `s3`, `gcs`, `azure`, `swift` and `oss`. The chart sets the driver under `persistence.imageChartStorage`.

These are the S3 fields this course uses:

| Field | What it sets |
| --- | --- |
| `type: s3` | Use the S3 driver |
| `s3.bucket` | The bucket name |
| `s3.region` | The region; any value an S3-compatible store accepts, here `us-east-1` |
| `s3.regionendpoint` | The URL of an S3-compatible store that is not Amazon S3 |
| `s3.existingSecret` | A Secret with the keys `REGISTRY_STORAGE_S3_ACCESSKEY` and `REGISTRY_STORAGE_S3_SECRETKEY` |
| `s3.v4auth` | Sign requests with AWS Signature Version 4 |
| `disableredirect` | Stop the registry from sending clients straight to the store |

Two of these need a sentence each. By default, the registry answers a request for a layer with a redirect to the store, so the client downloads the layer from the store directly. The chart's own comments say to switch this off for stores that do not support it. In this lab the store is only reachable inside the cluster at `s3.harbor-deps.svc.cluster.local`, so the course sets `disableredirect: true` and the registry streams every layer itself. And when `regionendpoint` is set, the registry addresses the bucket in the URL path (`/harbor/...`) instead of in the host name, which is what an in-cluster store needs.

The store in the playground is versitygw, an S3 gateway, with the empty bucket `harbor`. Check the bucket and the Secret with the keys, without printing the values:

<!-- astrona:playground:renew -->

```sh
kubectl -n harbor-deps exec deploy/s3-client -- aws s3 ls
kubectl -n harbor get secret harbor-s3 -o jsonpath='{.data}' | jq 'keys'
```

The first command lists the bucket `harbor`. The second lists the two key names the chart expects: `REGISTRY_STORAGE_S3_ACCESSKEY` and `REGISTRY_STORAGE_S3_SECRETKEY`.

## Job logs in the database

Every job `jobservice` runs writes a log. `jobservice.jobLoggers` decides where it goes: `file` (a file in the `jobservice` pod, the default), `database` (a table in PostgreSQL) or `stdout` (the pod's output). With `file` and no persistent volume, the logs disappear with the pod, and with two `jobservice` pods each one only has its own logs. The Harbor high-availability guide therefore says to set the job logger to `database` when you use object storage, so every replica, and the portal, read the same logs.

## Move the storage and the logs

Moving the storage changes where the registry looks for every layer. In this playground the registry's directory holds nothing worth keeping, so you can switch straight away. On a Harbor with real images, copy the contents of the old storage into the bucket first, or the artifacts in the database point at layers the registry can no longer find.

Save this as `harbor-values.yaml`, replacing the file you used for the database and Redis:

```yaml
expose:
  type: clusterIP
  tls:
    enabled: true
    certSource: secret
    secret:
      secretName: harbor-tls
  clusterIP:
    name: harbor
    ports:
      httpPort: 8080
      httpsPort: 8443
externalURL: https://harbor.localtest.me:8443
caSecretName: harbor-tls
harborAdminPassword: Harbor12345
existingSecretSecretKey: harbor-secretkey
persistence:
  enabled: false
  imageChartStorage:
    disableredirect: true
    type: s3
    s3:
      existingSecret: harbor-s3
      region: us-east-1
      bucket: harbor
      regionendpoint: http://s3.harbor-deps.svc.cluster.local:9000
      v4auth: true
trivy:
  enabled: false
metrics:
  enabled: false
database:
  type: external
  external:
    host: postgres.harbor-deps.svc.cluster.local
    port: "5432"
    username: harbor
    coreDatabase: registry
    existingSecret: harbor-external-db
    sslmode: disable
redis:
  type: external
  external:
    addr: redis.harbor-deps.svc.cluster.local:6379
jobservice:
  jobLoggers:
    - database
```

Apply it:

```sh
helm upgrade harbor harbor/harbor --version 1.19.4 --namespace harbor \
  --values harbor-values.yaml --wait --timeout 20m
```

Then prove the move with a real image. The helper `ws` runs a command in the `workstation` pod. Create the project `inventory` through the API, sign `regctl` in, and copy `podinfo` from its public registry into Harbor:

```sh
ws() { kubectl -n workstation exec -i deploy/workstation -- "$@"; }
ws curl -s -u admin:Harbor12345 -H 'Content-Type: application/json' \
  -d '{"project_name":"inventory","metadata":{"public":"false"}}' \
  https://harbor.localtest.me:8443/api/v2.0/projects
ws regctl registry login harbor.localtest.me:8443 -u admin -p Harbor12345
ws regctl image copy ghcr.io/stefanprodan/podinfo:6.15.0 harbor.localtest.me:8443/inventory/podinfo:6.15.0
```

The copy finishes without an error. Now look where the data went:

```sh
kubectl -n harbor-deps exec deploy/s3-client -- aws s3 ls s3://harbor/docker/registry/v2/repositories/inventory/
```

The bucket holds the folder `podinfo/` under `docker/registry/v2/repositories/inventory/`. That is the registry's storage layout: the repository folders hold links, and the layers themselves sit under `docker/registry/v2/blobs/`. The image left no file in any Harbor pod.

You have now moved all of Harbor's data out of its pods: the records to PostgreSQL, the queues to Redis, the images to a bucket and the job logs to the database, with every credential in a Secret. The pods hold only code. What is left is to do the whole move in one go, on a Harbor you did not prepare yourself.

## Common pitfalls

> [!WARNING]
> - **Switching storage on a Harbor with images.** The database still lists the artifacts, but the registry cannot find their layers in the new bucket. Copy the old storage first.
> - **Keeping redirects on for an internal store.** Clients get sent to an address they cannot reach. Set `disableredirect: true` when the store is not reachable from the clients.
> - **Writing `accesskey` and `secretkey` into the values.** Use `existingSecret` with the two `REGISTRY_STORAGE_S3_*` keys.
> - **Leaving `jobLoggers` on `file`.** Job logs disappear with the pod, and each `jobservice` replica sees only its own.

## Your mission: Move Harbor To External PostgreSQL, Redis And S3

You can now point Harbor at an external database, Redis and object store, and prove where each kind of data lands. The graded lab gives you a Harbor on its internal services and asks you to move all of it, with every credential read from a Secret, and to prove the move with a push and a pull.

The lab runs in its own cluster, so first pause your playground. Nothing in it is lost:

```sh
astrona stop ats-105-playground-010-01
```

Then start the lab:

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS105.git -c sections/section-010/module-01/labs/lab-01
```

The task is on the next page. Solve it on your own first. When you think you are done, send it for grading:

```sh
astrona submit -c sections/section-010/module-01/labs/lab-01
```

When the lab is done, remove it and start your playground again:

```sh
astrona destroy ats-105-lab-010-01
astrona start ats-105-playground-010-01
```
