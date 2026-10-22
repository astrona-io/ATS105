# Summary

A default Harbor installation keeps all of its data in its own pods. This module moved that data to services built for it, so that Harbor's pods hold nothing you cannot lose.

## What you learned

Harbor's components write to three stores. `core` and `jobservice` keep their records in PostgreSQL: projects, users, artifact records and policies, all in the database `registry`. `core` and `jobservice` also use Redis, each on its own Redis database number, for sessions, caches and the job queue. The `registry` component keeps image layers and manifests in its storage. `jobservice` writes a log for every job, and `portal` writes nothing. The health endpoint `/api/v2.0/health` reports every component and is the first check after any change.

With `database.type: external`, the chart starts no PostgreSQL of its own and connects to the server under `database.external`. The database must exist and be empty, and Harbor creates its tables on the first start. The password belongs in a Secret named in `existingSecret`, under the key `password`, because values passed to Helm end up in the release history. With `redis.type: external`, the chart connects to one Redis server, or to Redis Sentinel through `sentinelMasterSet`; Redis Cluster is not supported.

The registry stores images in object storage when `persistence.imageChartStorage.type` is `s3`. The bucket, the region and the `regionendpoint` of an S3-compatible store go into the values, and the keys go into a Secret with `REGISTRY_STORAGE_S3_ACCESSKEY` and `REGISTRY_STORAGE_S3_SECRETKEY`. When clients cannot reach the store, `disableredirect: true` makes the registry stream the layers itself. Job logs go to the database with `jobservice.jobLoggers: [database]`, so no log stays behind in a pod.

A move is proven by where the data lands, not by a successful `helm upgrade`. The key facts to remember are these:

- A `helm upgrade` replaces the values you passed before; start from `helm get values` and keep every setting.
- Switching to an empty database or an empty bucket starts Harbor fresh; copy real data before you switch.
- Prove the move three ways: the health endpoint, Harbor's tables in PostgreSQL, and a pushed image under `docker/registry/v2/` in the bucket.

<!-- astrona:playground:destroy -->
