# Question

Solve this question on: `terminal`

**Time:** about 45 minutes · **Topic:** High availability

## Scenario

A colleague "made Harbor highly available" on Friday. Since then, about half of all pulls of newly pushed images fail with "blob unknown" or "manifest unknown", and then work on the next try. Every pod is `Running` and Harbor's health endpoint says `healthy`. The release `harbor` in the namespace `harbor` uses the external PostgreSQL and Redis in `harbor-deps`; the S3 store there, with the bucket `harbor`, is ready but unused.

## Your task

Make Harbor consistent and highly available:

1. Every read of a freshly pushed image must succeed, on every try.
2. `portal`, `core`, `jobservice` and `registry` must each run at least **2** ready replicas.
3. `jobservice` must write job logs where every replica can read them.

Images pushed before the fix do not need to survive it.

## Constraints

- Use the bucket `harbor` in the S3 store at `http://s3.harbor-deps.svc.cluster.local:9000` (region `us-east-1`); its keys are in the Secret `harbor-s3`. No key may appear in the Helm values.
- Do not lower any replica count to make the problem go away.
- Do not uninstall the release.

## Done when

- The four Deployments each have at least 2 ready replicas.
- The registry stores images in the bucket `harbor`.
- `jobservice.jobLoggers` includes `database`.
- A newly pushed image can be read 20 times in a row without one failure, and its data is in the bucket `harbor`.
