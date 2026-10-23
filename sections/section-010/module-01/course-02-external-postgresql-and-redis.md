# External PostgreSQL And Redis

Harbor's records and queues are the first data to move, because they are the easiest to lose and the hardest to rebuild. The chart can stop running its own PostgreSQL and Redis and connect to servers you run instead. This part points a running Harbor at an external PostgreSQL and an external Redis, and keeps the database password out of the Helm values.

## What Harbor needs from an external database

The Harbor high-availability guide asks for three things before you switch. The PostgreSQL server must exist and be reachable from the cluster. The database must already exist and be empty; Harbor creates its own tables in it on the first start. And the user must own that database.

In the playground, the PostgreSQL server `postgres` in the namespace `harbor-deps` was started with the database `registry` and the user `harbor`. Check that it runs and that the database is still empty:

<!-- astrona:playground:renew -->

```sh
kubectl -n harbor-deps get pods,services
kubectl -n harbor-deps exec deploy/postgres -- psql -U harbor -d registry -c '\dt'
```

The first command lists the pods `postgres`, `redis`, `versitygw` and `s3-client`, and their Services. The second answers that it did not find any relations: the database exists, and it has no tables yet.

The chart reads the database settings from the `database` block of its values. With `database.type: external`, the chart starts no PostgreSQL of its own and uses the fields under `database.external`:

| Field | What it sets |
| --- | --- |
| `host`, `port` | Where the PostgreSQL server listens |
| `username` | The database user |
| `password` | The password, written into the values (avoid this) |
| `existingSecret` | A Secret that holds the password instead; the key must be `password` |
| `coreDatabase` | The database name; the default is `registry` |
| `sslmode` | `disable`, `require`, `verify-ca` or `verify-full`, as in PostgreSQL |

A password in the Helm values ends up in Helm's release history, which anyone with read access to the namespace's Secrets can decode. So the course always uses `existingSecret`. The Secret `harbor-external-db` was prepared for you. Check that it has the key the chart expects, without printing the value:

```sh
kubectl -n harbor get secret harbor-external-db -o jsonpath='{.data}' | jq 'keys'
```

The answer is a list with one key, `password`. The chart reads exactly that key name, so a Secret with any other key name leaves Harbor without a database password.

## What Harbor supports for Redis

Redis is simpler, because Harbor stores nothing in it that it cannot rebuild, but the rules are stricter. The `redis.external` block takes an address and, for Redis Sentinel, a master set:

| Field | What it sets |
| --- | --- |
| `addr` | `host:port` of one Redis server, or a comma-separated list of Sentinel addresses |
| `sentinelMasterSet` | The name of the Sentinel master set; set it only when `addr` lists Sentinels |
| `username`, `password`, `existingSecret` | Redis credentials; in a Secret the key must be `REDIS_PASSWORD` |
| `coreDatabaseIndex` and the other indexes | The Redis database number for each component |

Redis Sentinel is Redis's high-availability mode: Sentinel processes watch a primary server and promote a replica when it fails, and Harbor asks the Sentinels for the current primary. The Harbor high-availability guide says Redis Cluster, the sharded mode, is not supported, and that guide also says TLS to Redis is not. The chart 1.19.4 has a `tlsOptions` block for server-authenticated TLS, so the chart is newer than the guide on that point; this course runs Redis without TLS.

Check that the playground's Redis answers:

```sh
kubectl -n harbor-deps exec deploy/redis -- redis-cli ping
```

Redis answers `PONG`. It has no password, so the values below set only the address.

## Switch Harbor to the external database and Redis

A `helm upgrade` replaces the values you passed before, so start from what is installed. Save the current values to a file and look at them:

```sh
helm -n harbor get values harbor -o yaml > harbor-values-current.yaml
cat harbor-values-current.yaml
```

The file holds the settings the bootstrap used: the TLS Secret, the external URL, the administrator password, `existingSecretSecretKey`, and Trivy and metrics switched off. The new file keeps all of them and adds the `database` and `redis` blocks.

Save this as `harbor-values.yaml`:

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
```

Apply it:

```sh
helm upgrade harbor harbor/harbor --version 1.19.4 --namespace harbor \
  --values harbor-values.yaml --wait --timeout 20m
```

Then check the result:

```sh
kubectl -n harbor get statefulsets
kubectl -n harbor-deps exec deploy/postgres -- psql -U harbor -d registry -c '\dt' | head -20
ws() { kubectl -n workstation exec -i deploy/workstation -- "$@"; }
ws curl -s https://harbor.localtest.me:8443/api/v2.0/health | ws jq -r '.components[] | "\(.name) \(.status)"'
```

The StatefulSets `harbor-database` and `harbor-redis` are gone: the chart no longer runs its own. The external database now holds Harbor's tables, which `core` created when it started, and the health endpoint lists every component as `healthy`, including `database` and `redis`.

There is one consequence to state plainly. Harbor started on an empty database, so it created a fresh administrator from `harborAdminPassword` and nothing else; anything stored in the internal database stayed behind. In this playground nothing worth keeping was stored. On a Harbor with real data, you copy the database first with `pg_dump` and `pg_restore` and only then switch.

You now have Harbor's records and queues outside its pods, with the database password read from a Secret. The images, though, are still in a directory inside the registry pod, and the job logs are still files in the `jobservice` pod. Moving them is the last step.

## Common pitfalls

> [!WARNING]
> - **Writing the password into the values.** It ends up in Helm's release history. Use `existingSecret` and keep the password in a Secret.
> - **The wrong key in the Secret.** The chart reads the key `password` for the database and `REDIS_PASSWORD` for Redis, and nothing else.
> - **Running `helm upgrade` with only the new settings.** A values file replaces what you passed before. Start from `helm get values` and keep every setting.
> - **Pointing Harbor at a Redis Cluster.** Harbor supports one Redis server or Redis Sentinel, not Redis Cluster.
> - **Switching a Harbor with real data to an empty database.** Harbor starts fresh and the old records stay behind. Copy the database first.
