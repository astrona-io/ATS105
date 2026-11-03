# Solution: Rotate The Harbor Database Password

Work the task yourself first. Running `astrona submit -c sections/section-010/module-03/labs/lab-01` after a step tells you which checks pass, without telling you what is left.

The grader checks four things: PostgreSQL accepts the new password and refuses the old one, the Secret holds the new password and the Helm values hold none, the running `core` pod holds the new password, and Harbor is healthy with a working push and pull.

## Step 1: Find who reads the Secret

```sh
kubectl -n harbor get deployments -o json | jq -r '.items[] | select(.spec.template.spec.containers[].env[]?.valueFrom.secretKeyRef.name == "harbor-external-db") | .metadata.name'
```

The answer is `harbor-core`. That Deployment needs a restart at the end.

## Step 2: Change the role

```sh
kubectl -n harbor-deps exec deploy/postgres -- psql -U harbor -d registry -c "ALTER ROLE harbor PASSWORD 'rotated-db-password-2'"
```

PostgreSQL prints `ALTER ROLE`. Connections that are open keep working.

## Step 3: Update the Secret

Save this as `secret-harbor-external-db.yaml`:

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

## Step 4: Restart core

```sh
kubectl -n harbor rollout restart deployment/harbor-core
kubectl -n harbor rollout status deployment/harbor-core --timeout=300s
```

## Step 5: Prove it before the grader does

```sh
kubectl -n harbor exec deploy/harbor-core -- sh -c 'printf %s "$POSTGRESQL_PASSWORD" | cksum'
kubectl -n harbor get secret harbor-external-db -o jsonpath='{.data.password}' | base64 -d | cksum
ws() { kubectl -n workstation exec -i deploy/workstation -- "$@"; }
ws curl -s https://harbor.localtest.me:8443/api/v2.0/health | ws jq -r '.status'
```

The two checksums are equal, and the status is `healthy`. Then submit:

```sh
astrona submit -c sections/section-010/module-03/labs/lab-01
```

## Why the obvious shortcuts are wrong

| Shortcut | What happens |
| --- | --- |
| Update the Secret only | `core` keeps the old password; the grader finds it in the pod |
| Restart `core` before `ALTER ROLE` | The new pod cannot log in and never becomes ready |
| Put the new password into the Helm values and upgrade | The password is visible in `helm get values`; the grader refuses it |

## Common mistakes

- Using `kubectl create secret` without `--dry-run` on a Secret that exists, which fails with `AlreadyExists`.
- Reading `rollout status` as proof without comparing the password.
