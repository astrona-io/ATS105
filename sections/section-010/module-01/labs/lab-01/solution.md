# Solution: Move Harbor To External PostgreSQL, Redis And S3

Work the task yourself first. Running `astrona submit -c sections/section-010/module-01/labs/lab-01` after a step tells you which checks pass, without telling you what is left.

The grader checks four things: the Helm values name the external services and the Secrets and hold no password, Harbor reports healthy, a new image pushes and pulls and lands in the bucket `harbor`, and Harbor's tables are in the external database.

## Step 1: See what is installed

Save the current values and look at the workloads:

```sh
helm -n harbor get values harbor -o yaml > harbor-values-current.yaml
cat harbor-values-current.yaml
kubectl -n harbor get deployments,statefulsets
```

The values hold the TLS Secret, the external URL, the administrator password, `existingSecretSecretKey`, and Trivy and metrics off. The StatefulSets `harbor-database` and `harbor-redis` are the internal services you are replacing.

## Step 2: Check the Secrets

Check that each Secret has the key the chart expects, without printing the values:

```sh
kubectl -n harbor get secret harbor-external-db -o jsonpath='{.data}' | jq 'keys'
kubectl -n harbor get secret harbor-s3 -o jsonpath='{.data}' | jq 'keys'
```

`harbor-external-db` has the key `password`, and `harbor-s3` has `REGISTRY_STORAGE_S3_ACCESSKEY` and `REGISTRY_STORAGE_S3_SECRETKEY`. Those are the names the chart reads.

## Step 3: Write the complete values file

A `helm upgrade` with a values file replaces the values passed before, so the new file keeps every current setting and adds the four new blocks. Save this as `harbor-values.yaml`:

```yaml
expose:
  type: clusterIP
  tls:
    enabled: true
    certSource: secret
    secret:
      secretName: harbor-tls
  clusterIP:
    name: harbor
    ports:
      httpPort: 8080
      httpsPort: 8443
externalURL: https://harbor.localtest.me:8443
caSecretName: harbor-tls
harborAdminPassword: Harbor12345
existingSecretSecretKey: harbor-secretkey
persistence:
  enabled: false
  imageChartStorage:
    disableredirect: true
    type: s3
    s3:
      existingSecret: harbor-s3
      region: us-east-1
      bucket: harbor
      regionendpoint: http://s3.harbor-deps.svc.cluster.local:9000
      v4auth: true
trivy:
  enabled: false
metrics:
  enabled: false
database:
  type: external
  external:
    host: postgres.harbor-deps.svc.cluster.local
    port: "5432"
    username: harbor
    coreDatabase: registry
    existingSecret: harbor-external-db
    sslmode: disable
redis:
  type: external
  external:
    addr: redis.harbor-deps.svc.cluster.local:6379
jobservice:
  jobLoggers:
    - database
```

## Step 4: Upgrade the release

Apply it:

```sh
helm upgrade harbor harbor/harbor --version 1.19.4 --namespace harbor \
  --values harbor-values.yaml --wait --timeout 20m
```

Then check the result:

```sh
kubectl -n harbor get statefulsets
ws() { kubectl -n workstation exec -i deploy/workstation -- "$@"; }
ws curl -s https://harbor.localtest.me:8443/api/v2.0/health | ws jq -r '.status'
```

The internal StatefulSets are gone and the health status is `healthy`. If it is not, read the logs of the component that is not healthy, for example `kubectl -n harbor logs deploy/harbor-core`, before you change anything else.

## Step 5: Push an image and find its data

Create the project, sign in and copy the image:

```sh
ws curl -s -u admin:Harbor12345 -H 'Content-Type: application/json' \
  -d '{"project_name":"inventory","metadata":{"public":"false"}}' \
  https://harbor.localtest.me:8443/api/v2.0/projects
ws regctl registry login harbor.localtest.me:8443 -u admin -p Harbor12345
ws regctl image copy ghcr.io/stefanprodan/podinfo:6.15.0 harbor.localtest.me:8443/inventory/podinfo:6.15.0
```

Prove where the data went:

```sh
kubectl -n harbor-deps exec deploy/s3-client -- aws s3 ls s3://harbor/docker/registry/v2/repositories/inventory/
kubectl -n harbor-deps exec deploy/postgres -- psql -U harbor -d registry -c 'select name from project'
```

The bucket holds `podinfo/`, and the external database lists the projects `library` and `inventory`.

## Step 6: Submit

```sh
astrona submit -c sections/section-010/module-01/labs/lab-01
```

## Why the obvious shortcuts are wrong

| Shortcut | What happens |
| --- | --- |
| Put `password: harbor-db-password` in the values | Harbor works, but the password sits in Helm's release history; the grader refuses it |
| Upgrade with only the new blocks | The certificate, external URL and `secretKey` settings fall back to the chart defaults |
| Keep `jobLoggers` on `file` | Job logs stay in a pod and are lost with it |
| Uninstall and install again | Not needed, and it would also replace Harbor's generated internal secrets |

## Common mistakes

- Forgetting `disableredirect: true`, so the registry sends clients to an address they cannot reach.
- Writing the S3 keys into `accesskey` and `secretkey` instead of using `existingSecret`.
- Reading a successful `helm upgrade` as proof. Check health, the bucket and the database.
