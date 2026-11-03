# Question

Solve this question on: `terminal`

**Time:** about 30 minutes · **Topic:** High availability

## Scenario

Harbor runs two replicas of `portal`, `core`, `jobservice` and `registry`, but the platform team is about to drain nodes for maintenance. Nothing stops Kubernetes from evicting both replicas of one component at the same time, and nothing stops the scheduler from placing both on the same node. The release `harbor` in the namespace `harbor` runs on the external PostgreSQL, Redis and S3 bucket in `harbor-deps`.

## Your task

Upgrade the release `harbor` (chart `harbor/harbor` version `1.19.4`) so that:

1. `portal`, `core`, `jobservice` and `registry` each have a PodDisruptionBudget with `minAvailable: 1`, and each budget allows at least one disruption.
2. `core` and `registry` have a topology spread constraint on the label `kubernetes.io/hostname` with `maxSkew: 1` and `whenUnsatisfiable: ScheduleAnyway`.
3. Everything else stays as it is: two replicas per component, the database job logger, the external services, the certificate, the URL, the administrator password and the `secretKey` settings.

## Constraints

- Do not change the services in `harbor-deps`.
- Do not uninstall the release.
- Create the budgets and the constraints through the Helm values, not with `kubectl apply`: the chart owns these objects.

## Done when

- `kubectl -n harbor get pdb` lists a budget for each of the four components with `ALLOWED DISRUPTIONS` of at least 1.
- The Deployments of `core` and `registry` carry the spread constraint.
- The four Deployments still have at least 2 ready replicas.
- `/api/v2.0/health` reports every component `healthy`.
- A push and a pull through Harbor work.
