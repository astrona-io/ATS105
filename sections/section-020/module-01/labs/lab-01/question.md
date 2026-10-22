# Question

Solve this question on: `terminal`

**Time:** about 30 minutes · **Topic:** High availability

## Scenario

Harbor is the only registry for every deployment pipeline in the company. Last week a node restart took `harbor-core` down for two minutes and every pipeline failed. The release `harbor` in the namespace `harbor` already runs on the external PostgreSQL, Redis and S3 bucket in `harbor-deps`, but every component runs once, and `jobservice` still writes its job logs to files.

## Your task

Upgrade the release `harbor` (chart `harbor/harbor` version `1.19.4`) so that:

1. `portal`, `core`, `jobservice` and `registry` each run at least **2** ready replicas.
2. `jobservice` writes job logs to the database.
3. Everything else stays as it is: the external services, the certificate, the URL, the administrator password and the `secretKey` settings.

## Constraints

- Do not change the services in `harbor-deps`.
- Do not uninstall the release.
- Scale through the Helm values, not with `kubectl scale`: the next `helm upgrade` would undo a manual scale.

## Done when

- The four Deployments each have at least 2 ready replicas.
- `jobservice.jobLoggers` includes `database`.
- `/api/v2.0/health` reports every component `healthy`.
- Pushes and pulls keep working while one `core` pod and one `registry` pod are deleted. The grader deletes them itself.
