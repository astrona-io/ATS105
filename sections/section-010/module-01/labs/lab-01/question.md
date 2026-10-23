# Question

Solve this question on: `terminal`

**Time:** about 30 minutes · **Topic:** Running Harbor on external services

## Scenario

The platform team wants Harbor's pods to hold no data. Today the release `harbor` in the namespace `harbor` runs on its internal PostgreSQL and Redis and stores images in a directory inside the registry pod. The external services are ready in the namespace `harbor-deps`, and the Secrets with their credentials are ready in the namespace `harbor`.

| Service | Address | Credentials |
| --- | --- | --- |
| PostgreSQL | `postgres.harbor-deps.svc.cluster.local:5432`, database `registry` | user `harbor`, password in the Secret `harbor-external-db` (key `password`) |
| Redis | `redis.harbor-deps.svc.cluster.local:6379` | none |
| S3 store | `http://s3.harbor-deps.svc.cluster.local:9000`, bucket `harbor`, region `us-east-1` | keys in the Secret `harbor-s3` |

## Your task

Upgrade the release `harbor` (chart `harbor/harbor` version `1.19.4`) so that:

1. Harbor uses the external PostgreSQL, with the password read from the Secret `harbor-external-db`.
2. Harbor uses the external Redis.
3. The registry stores images in the bucket `harbor`, with the keys read from the Secret `harbor-s3`.
4. `jobservice` writes job logs to the database.
5. Harbor keeps its current certificate, external URL, administrator password and `secretKey` settings.

Then push `ghcr.io/stefanprodan/podinfo:6.15.0` into Harbor as `inventory/podinfo:6.15.0`. The project `inventory` does not exist yet.

## Constraints

- No password or key may appear in the Helm values. Use the Secrets as they are.
- Do not delete the namespace `harbor` or uninstall the release; upgrade it.
- Do not change the services in `harbor-deps`.

## Done when

- `helm -n harbor get values harbor` shows external database, Redis and S3 settings that name the Secrets, and no password.
- No `harbor-database` or `harbor-redis` StatefulSet runs in the namespace `harbor`.
- `/api/v2.0/health` reports every component `healthy`.
- A new image can be pushed and pulled, its data is in the bucket `harbor`, and Harbor's tables are in the external database.
