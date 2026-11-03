# Question

Solve this question on: `terminal`

**Time:** about 30 minutes · **Topic:** Rotating Harbor's credentials

## Scenario

The security team found the database password of Harbor in a ticket and requires a rotation. Harbor in the namespace `harbor` runs on the PostgreSQL server `postgres` in the namespace `harbor-deps`, with the password in the Secret `harbor-external-db`.

## Your task

Change the password of the PostgreSQL role `harbor` to `rotated-db-password-2` and make Harbor use it:

1. The role `harbor` accepts `rotated-db-password-2` and no longer accepts the old password `harbor-db-password`.
2. The Secret `harbor-external-db` in the namespace `harbor` holds the new password under the key `password`.
3. The running `core` pod uses the new password.
4. Harbor reports every component healthy, and a new image can be pushed and pulled.

## Constraints

- No database password may appear in the Helm values. The release must keep reading it from the Secret.
- Do not uninstall the release, delete the namespace or change the Helm values.
- Do not delete the PostgreSQL pod or its data.

## Done when

- A login to PostgreSQL over the network with the new password works, and a login with the old one is refused.
- `core` has restarted after the Secret changed and holds the new password in `POSTGRESQL_PASSWORD`.
- `/api/v2.0/health` reports every component `healthy`.
- A new push and pull of `inventory/podinfo` works.
