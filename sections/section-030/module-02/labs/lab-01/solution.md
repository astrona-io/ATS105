# Solution: Take A Complete Harbor Backup

Work the task yourself first. Running `astrona submit -c sections/section-030/module-02/labs/lab-01` after a step tells you which checks pass, without telling you what is left.

The grader checks four things: a valid custom-format dump with the project `inventory`, a bucket copy with the same number of objects, the Secret copy and the values backup, and a healthy Harbor.

## Step 1: Dump the database

```sh
kubectl -n harbor-deps exec deploy/postgres -- pg_dump -U harbor -d registry -Fc -f /backup/registry.dump
kubectl -n harbor-deps exec deploy/postgres -- pg_restore --list /backup/registry.dump
```

The second command lists the contents of the archive. A plain-text dump would fail here, which is why `-Fc` matters.

## Step 2: Copy the bucket

```sh
s3() { kubectl -n harbor-deps exec -i deploy/s3-client -- aws s3 "$@"; }
s3 sync s3://harbor s3://harbor-backup
s3 ls s3://harbor --recursive | wc -l
s3 ls s3://harbor-backup --recursive | wc -l
```

Both counts are the same.

## Step 3: Copy the Secrets and the values

```sh
kubectl -n harbor-deps create secret generic harbor-backup-copy \
  --from-literal=tls.crt="$(kubectl -n harbor get secret harbor-tls -o jsonpath='{.data.tls\.crt}' | base64 -d)" \
  --from-literal=tls.key="$(kubectl -n harbor get secret harbor-tls -o jsonpath='{.data.tls\.key}' | base64 -d)" \
  --from-literal=ca.crt="$(kubectl -n harbor get secret harbor-tls -o jsonpath='{.data.ca\.crt}' | base64 -d)" \
  --from-literal=secretKey="$(kubectl -n harbor get secret harbor-secretkey -o jsonpath='{.data.secretKey}' | base64 -d)"
helm -n harbor get values harbor -o yaml > harbor-values.yaml
kubectl -n harbor-deps create configmap harbor-values-backup --from-file=values.yaml=harbor-values.yaml
```

Then submit:

```sh
astrona submit -c sections/section-030/module-02/labs/lab-01
```

## Why the obvious shortcuts are wrong

| Shortcut | What happens |
| --- | --- |
| `pg_dump` without `-Fc` | The file is plain SQL and `pg_restore` cannot read it |
| Dumping before the content exists | The dump has no project `inventory` |
| Copying only the database | The restored Harbor has metadata and no layers |
| Leaving out `secretKey` | Stored credentials cannot be decrypted after a restore |

## Common mistakes

- Putting the dump only on your machine. It belongs in the `postgres` pod folder that survives a dropped database.
- Reading `sync` with no error as proof. Compare the object counts.
