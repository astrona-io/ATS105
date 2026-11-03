# Which Credentials Harbor Holds

A Harbor installation passes secrets between at least six places: the browser session, the components, the database, Redis, the object store and the administrator account. The chart can generate most of them, but a generated value lives inside the release. A production installation keeps them in Kubernetes Secrets that a person or a secret manager controls. This part lists each credential and the exact chart value and key name that connects it to an existing Secret.

## The list

The chart's `values.yaml` at tag `v1.19.4` defines these. Each row shows what the value protects, the chart value that names a Secret you own, and the key the Secret must contain.

| Credential | Chart value | Key in the Secret |
| --- | --- | --- |
| Encryption key (`secretKey`) | `existingSecretSecretKey` | `secretKey` |
| Administrator password | `existingSecretAdminPassword` | `HARBOR_ADMIN_PASSWORD` (set another name in `existingSecretAdminPasswordKey`) |
| Database password | `database.external.existingSecret` | `password` |
| Redis password | `redis.external.existingSecret` | `REDIS_PASSWORD` (and `REDIS_USERNAME` with ACL mode) |
| S3 access and secret key | `persistence.imageChartStorage.s3.existingSecret` | `REGISTRY_STORAGE_S3_ACCESSKEY`, `REGISTRY_STORAGE_S3_SECRETKEY` |
| Secret between `core` and its callers | `core.existingSecret` | `secret` |
| Secret for `jobservice` | `jobservice.existingSecret` | `JOBSERVICE_SECRET` (set another name in `existingSecretKey`) |
| Registry HTTP secret | `registry.existingSecret` | `REGISTRY_HTTP_SECRET` |
| Registry basic-authentication password | `registry.credentials.existingSecret` | `REGISTRY_PASSWD` and `REGISTRY_HTPASSWD` |
| Cross-site request forgery key | `core.existingXsrfSecret` | `CSRF_KEY` (set another name in `existingXsrfSecretKey`) |

The first five rows are the ones a platform team always manages. The others are shared secrets between components. The chart generates them on the first install and keeps them on later upgrades.

## See them in the playground

The playground sets three of the Secrets. List them and look at their key names without printing the values:

<!-- astrona:playground:renew -->

```sh
kubectl -n harbor get secrets
kubectl -n harbor get secret harbor-external-db -o jsonpath='{.data}' | jq 'keys'
kubectl -n harbor get secret harbor-s3 -o jsonpath='{.data}' | jq 'keys'
```

The first command lists the Secrets in the namespace, including the ones the chart created, such as `harbor-core`, `harbor-registry` and `harbor-jobservice`. The second prints `["password"]`. The third prints the two S3 key names.

## Where a pod reads each value

A Secret is useful only when a pod receives it. For the database, `core` gets the environment variable `POSTGRESQL_PASSWORD` from the key `password` of your Secret. Check it on the running pod, but only the variable name, not the value:

```sh
kubectl -n harbor get deployment harbor-core -o json | jq -r '.spec.template.spec.containers[0].env[] | select(.name=="POSTGRESQL_PASSWORD") | .valueFrom.secretKeyRef'
```

The answer shows the Secret name `harbor-external-db` and the key `password`. The encryption key works differently: it is mounted as a file, not read as an environment variable. The Deployment mounts the Secret named in `existingSecretSecretKey` as a volume called `secret-key`, and `core` reads the file when it starts.

You now know which credentials exist, which value names each Secret, and how `core` receives the database password and the encryption key. The encryption key deserves its own part, because losing it is the one mistake that cannot be corrected by a restart.

## Common pitfalls

> [!WARNING]
> - **Using another key name in a Secret.** The pod cannot start or reads nothing; use the exact key names above.
> - **Putting a password in the Helm values.** `helm get values` prints it to anyone with access to the release.
> - **Assuming the chart watches your Secrets.** It does not; a changed Secret needs a restart.
> - **Mixing up `existingSecret` and a value with the same name.** For the database it is `database.external.existingSecret`.
> - **Printing Secret values into a shared terminal or log.** Print key names unless you must see the value.
