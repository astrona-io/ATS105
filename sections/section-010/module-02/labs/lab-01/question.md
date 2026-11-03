# Question

Solve this question on: `terminal`

**Time:** about 30 minutes · **Topic:** Securing Harbor's traffic

## Scenario

A security review of the platform found that the Harbor components in the namespace `harbor` talk to each other over plain HTTP. The review requires that traffic between `core`, `jobservice`, `registry` and `portal` is encrypted. Harbor already runs on the external PostgreSQL, Redis and S3 store in the namespace `harbor-deps` and holds the image `inventory/podinfo:6.15.0`.

## Your task

Upgrade the release `harbor` (chart `harbor/harbor` version `1.19.4`) so that:

1. Internal TLS is enabled, with certificates that the chart generates.
2. Harbor keeps its external database, Redis and S3 settings, its certificate Secret `harbor-tls`, its external URL and its `secretKey` Secret.
3. Harbor reports every component healthy after the upgrade.

## Constraints

- No password or key may appear in the Helm values.
- Do not uninstall the release or delete the namespace `harbor`.
- Do not change the services in `harbor-deps`.
- Do not remove values from the release: a values file that holds only the new block would drop the external services.

## Done when

- `core` listens on port `8443` and the Secrets `harbor-core-internal-tls`, `harbor-jobservice-internal-tls`, `harbor-registry-internal-tls` and `harbor-portal-internal-tls` exist.
- `helm -n harbor get values harbor` still shows the external services, the Secrets and the external URL.
- `/api/v2.0/health` reports every component `healthy`.
- A new image can be pushed and pulled through `https://harbor.localtest.me:8443`, and `inventory/podinfo:6.15.0` still pulls.
