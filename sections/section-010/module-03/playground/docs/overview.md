# Overview: Harbor Secrets, Keys And Credentials (Playground)

This is a **playground**, not a lab. It starts a fresh cluster with Harbor on external services and then waits. There is no task, no `astrona submit` and no pass or fail. Explore, break things, `astrona destroy`, start over.

## What's in the box

- A single-node `kind` cluster, with `kubectl` pointed at it and Helm 3.22.1 on your machine with the chart repository `harbor` added.
- **Harbor 2.15.4**, the release `harbor` (chart 1.19.4) in the namespace `harbor`, on the external PostgreSQL, Redis and S3 bucket `harbor` in the namespace `harbor-deps`, with job logs in the database. Each component runs **one** replica.
- The project `inventory` with `inventory/podinfo:6.15.0`.
- The Secret `harbor-tls` holds the certificate and the lab certificate authority. The `workstation` pod with `regctl`, `curl` and `jq`, trusting Harbor's certificate. The administrator is `admin` / `Harbor12345` (lab-only).

## Helpers

Paste these once in each new terminal. `ws` runs a command in the workstation. `secret_keys` prints the key names of a Secret in the namespace `harbor`, never the values. `readers` lists the Deployments that read a Secret.

```sh
ws() { kubectl -n workstation exec -i deploy/workstation -- "$@"; }
secret_keys() { kubectl -n harbor get secret "$1" -o jsonpath='{.data}' | jq -r 'keys | join(", ")'; }
readers() {
  kubectl -n harbor get deployments -o json | jq -r --arg name "$1" '.items[] | select(.spec.template.spec.containers[].env[]?.valueFrom.secretKeyRef.name == $name) | .metadata.name'
}
```

Use them like this: `secret_keys harbor-s3`, `readers harbor-external-db`.

## Practice tasks

- Run `secret_keys` for every Secret in the namespace `harbor` and match each key to a chart value.
- Run `readers harbor-s3`. Find which Deployment gets the S3 keys, then read how it receives them.
- Rotate the database password by hand, in the right order, and compare the checksum of `POSTGRESQL_PASSWORD` in the pod with the Secret.
- Update only the Secret, wait two minutes and read the `harbor-core` log. Find out when the old password stops working by opening new connections (for example, scale `core` to two replicas).
- Change `harborAdminPassword` in the values, upgrade, and log in with both passwords.
