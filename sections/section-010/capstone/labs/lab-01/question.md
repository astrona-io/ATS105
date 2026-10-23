# Question

Solve this question on: `terminal`

**Time:** about 45 minutes · **Topic:** Running Harbor on external services

## Scenario

A colleague moved the release `harbor` in the namespace `harbor` to the external services in `harbor-deps` and went on holiday before checking it. Harbor does not become healthy. Pods restart, and the colleague's note only says "PostgreSQL, Redis and S3 are configured, the Secrets are in place".

The external services themselves are healthy and must stay as they are:

| Service | Address | Credentials |
| --- | --- | --- |
| PostgreSQL | `postgres.harbor-deps.svc.cluster.local:5432`, database `registry` | user `harbor`; the password is in the Secret `harbor-external-db` |
| Redis | `redis.harbor-deps.svc.cluster.local:6379` | none |
| S3 store | `http://s3.harbor-deps.svc.cluster.local:9000`, bucket `harbor` | keys in the Secret `harbor-s3` |

## Your task

Find every reason Harbor cannot reach its database, Redis and image storage, and fix them so that Harbor is healthy and stores new images in the bucket `harbor`. There is more than one fault, and they are in different places.

## Constraints

- No password or key may appear in the Helm values.
- Do not change the services or the buckets in `harbor-deps`.
- Do not uninstall the release; upgrade it.

## Done when

- The Helm values name the external PostgreSQL, Redis on port `6379` and the bucket `harbor`, and read credentials from Secrets.
- The Secret `harbor-external-db` holds the database password under the key the chart reads.
- `/api/v2.0/health` reports every component `healthy`.
- A new image can be pushed and pulled, and its data is in the bucket `harbor`.
