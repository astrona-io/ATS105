# Rotating A Credential

Security rules often require that database passwords change on a schedule, or at once after a leak. Harbor does not change a password for you. A rotation has three actors: PostgreSQL, which holds the password; a Kubernetes Secret, which stores it for Harbor; and the pods, which read the Secret once at start. If you change one without the others, Harbor loses its database. This part shows the order that keeps Harbor working.

## Why a Secret change alone is not enough

A pod receives a value from a Secret through an environment variable when the container starts. Kubernetes never updates that variable in a running container. The chart adds a checksum annotation to the pod template for the Secrets it owns, so a change in them restarts the pods. That checksum cannot cover a Secret that you own, such as `harbor-external-db`. So after you edit it, `core` keeps running with the old password until something restarts it.

This is also the reason to find every reader of a Secret before you change it. Ask the cluster instead of remembering:

<!-- astrona:playground:renew -->

```sh
kubectl -n harbor get deployments -o json | jq -r '.items[] | select(.spec.template.spec.containers[].env[]?.valueFrom.secretKeyRef.name == "harbor-external-db") | .metadata.name'
```

The answer is `harbor-core`. Any Deployment in the list needs a restart after the rotation.

## The order that works

PostgreSQL accepts a new password for a role as soon as you run `ALTER ROLE`. Connections that are already open keep working. New connections need the new password. Harbor's connection pool opens new connections over time, so the old password must stop working only after the pods use the new one. With one `core` replica, a short interruption is unavoidable. The steps are:

1. Change the password in PostgreSQL.
2. Update the Secret.
3. Restart every pod that reads the Secret.
4. Prove that Harbor uses the new password.

Step 1 changes the role. The pod `postgres` accepts local connections without a password, so the command needs no secret:

```sh
kubectl -n harbor-deps exec deploy/postgres -- psql -U harbor -d registry -c "ALTER ROLE harbor PASSWORD 'rotated-db-password-2'"
```

PostgreSQL prints `ALTER ROLE`. Step 2 puts the same value into the Secret. Save this as `secret-harbor-external-db.yaml`:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: harbor-external-db
  namespace: harbor
type: Opaque
stringData:
  password: rotated-db-password-2
```

Apply it:

```sh
kubectl apply -f secret-harbor-external-db.yaml
```

Then restart `core` and wait for it:

```sh
kubectl -n harbor rollout restart deployment/harbor-core
kubectl -n harbor rollout status deployment/harbor-core --timeout=300s
```

## Prove it

Do not accept a green rollout as proof. Compare what the pod holds with what the database accepts. This command prints a checksum of the variable in the pod and a checksum of the Secret value, which must match, and it proves that the new password logs in over the network and that the old one does not:

```sh
kubectl -n harbor exec deploy/harbor-core -- sh -c 'printf %s "$POSTGRESQL_PASSWORD" | cksum'
kubectl -n harbor get secret harbor-external-db -o jsonpath='{.data.password}' | base64 -d | cksum
kubectl -n harbor-deps exec deploy/postgres -- sh -c 'PGPASSWORD=rotated-db-password-2 psql -h "$(hostname -i)" -U harbor -d registry -tAc "select 1"'
kubectl -n harbor-deps exec deploy/postgres -- sh -c 'PGPASSWORD=harbor-db-password psql -h "$(hostname -i)" -U harbor -d registry -tAc "select 1"'
```

The two checksums are equal. The third command prints `1`. The fourth fails with an authentication error, because the old password no longer works over the network. If you skipped the restart, the first two checksums differ.

You now know that a rotation is an ordered change across PostgreSQL, a Secret and the pods that read it, and how to prove each step. The same order applies to the Redis password and the S3 keys, with one difference: for S3, the store must accept both keys until the pods have restarted, so a second key pair is added first.

## Common pitfalls

> [!WARNING]
> - **Updating the Secret and forgetting the restart.** Harbor looks fine until the pool opens a new connection.
> - **Restarting before the role has the new password.** The new pod cannot log in and does not become ready.
> - **Putting the new password in the Helm values to "make Helm restart the pods".** The password is then visible in `helm get values`.
> - **Finding the readers from memory.** Search the Deployments, as shown above.
> - **Proving the rotation with the old password.** Test the new one and test that the old one is refused.

## Your mission: Rotate The Harbor Database Password

You can now change the database password in the right order and prove it. The graded lab gives you a Harbor that works with the current password and asks you to change it to a given value without leaving the password in the Helm values.

The lab runs in its own cluster, so first pause your playground. Nothing in it is lost:

```sh
astrona stop ats-105-playground-010-03
```

Then start the lab:

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS105.git -c sections/section-010/module-03/labs/lab-01
```

The task is on the next page. Solve it on your own first. When you think you are done, send it for grading:

```sh
astrona submit -c sections/section-010/module-03/labs/lab-01
```

When the lab is done, remove it and start your playground again:

```sh
astrona destroy ats-105-lab-010-03
astrona start ats-105-playground-010-03
```
