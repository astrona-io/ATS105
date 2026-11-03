# Connection Budgets And Redis Failover

Scaling a component multiplies everything it opens: each `core` replica holds its own pool of database connections. PostgreSQL accepts a fixed number of connections, and the number is shared by every replica of every component. If the sum is larger than the limit, the new pods start and then fail on their first query. This part shows how to calculate the budget and how Harbor connects to a Redis that is itself highly available.

## The database connection budget

The `database` block of the chart sets two limits that apply to each pod of `core` and its exporter: `maxIdleConns`, the number of idle connections that stay open, with the default `100`, and `maxOpenConns`, the largest number of open connections, with the default `900`. These are ceilings, not what Harbor uses all the time, but a busy `core` can reach them. The chart comment says that the PostgreSQL image of the chart's own database allows 1024 connections.

The stock PostgreSQL image allows far fewer. Check the server limit in the playground and count the connections that are open now:

<!-- astrona:playground:renew -->

```sh
kubectl -n harbor-deps exec deploy/postgres -- psql -U harbor -d registry -tAc "show max_connections"
kubectl -n harbor-deps exec deploy/postgres -- psql -U harbor -d registry -tAc "select count(*) from pg_stat_activity where datname = 'registry'"
```

The first command prints `100`, the PostgreSQL default. The second prints the number of connections that Harbor holds at this moment, which is far below the limit. With two `core` replicas and the default `maxOpenConns` of `900`, the ceiling is 1800. It is higher than the server allows, so one busy moment can fail.

## How to size it

Start from the server. `max_connections` minus a reserve for administrators and other clients is what Harbor may use. Divide that by the number of `core` replicas, including the extra pod during a rolling update, and set `maxOpenConns` to the result. Set `maxIdleConns` lower than or equal to it. For a server with 200 connections, a reserve of 20 and two `core` replicas plus one surge pod, `maxOpenConns` is 60.

```yaml
database:
  maxIdleConns: 20
  maxOpenConns: 60
```

Raising the server limit works too, but each connection costs memory on the server, so the better habit is to set both sides. Set the limits in the values and read them back from the ConfigMap of `core`.

## Redis and high availability

Harbor keeps its job queue, sessions and caches in Redis. If that Redis is a single server, it is a single point of failure for the whole of Harbor. The chart supports two forms of external Redis. For a single server, `redis.external.addr` is `host:port`. For Redis Sentinel, `addr` is a comma-separated list of Sentinel addresses, and `sentinelMasterSet` names the master set. The chart does not support Redis Cluster. The values comment names only `redis` and `redis+sentinel`.

```yaml
redis:
  type: external
  external:
    addr: sentinel-0.redis:26379,sentinel-1.redis:26379,sentinel-2.redis:26379
    sentinelMasterSet: mymaster
```

The playground has one Redis server, so you cannot start a failover here; read the values as a pattern. Each component keeps its own database index: `core` uses `0`, `jobservice` `1`, `registry` `2` and the Trivy adapter `5`. The `core` index must stay `0`. The chart also has `redis.external.tlsOptions` for a TLS connection, which supports only server authentication. Mutual TLS to Redis is not supported.

You now know how replicas multiply database connections, how to size the pools against the server limit, and how Harbor reaches a Sentinel-managed Redis. With the budgets, spread rules, rolling updates and connection limits, you have seen the settings that turn a scaled Harbor into one that survives disruption.

## Common pitfalls

> [!WARNING]
> - **Scaling `core` and leaving `maxOpenConns` at 900.** The sum can pass the server limit.
> - **Counting only the running replicas.** A rolling update adds a pod.
> - **Using a Redis Cluster address.** The chart supports a single server and Sentinel.
> - **Setting `sentinelMasterSet` for a plain Redis.** Leave it empty.
> - **Changing the `core` Redis index.** It must be `0`.
