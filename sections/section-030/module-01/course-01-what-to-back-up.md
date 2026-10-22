# What To Back Up

A backup plan starts with a list, and for Harbor the list is longer than "the database". This part names every piece a restore needs, explains what goes wrong without each one, and takes each backup on the playground, so the copies exist before anything is deleted.

## The five pieces

Harbor's data and the keys to read it are spread over five places. The table lists them with what breaks when a restore lacks one:

| Piece | Where it is in this course | Without it, a restored Harbor... |
| --- | --- | --- |
| The database | The database `registry` on `postgres` | has no projects, users, artifacts or policies |
| The image storage | The bucket `harbor` | lists artifacts whose layers it cannot find; pulls fail |
| The TLS certificate | The Secret `harbor-tls` | presents a new certificate that clients do not trust |
| `secretKey` | The Secret `harbor-secretkey` | cannot decrypt the passwords it stored, such as registry endpoint credentials |
| The Helm values | The release `harbor` | is installed with different settings, or not at all |

Two rows need more explanation. `secretKey` is a 16-character key Harbor uses to encrypt secrets it keeps in its database, for example the password of a remote registry endpoint used for replication. The database backup holds those passwords only in encrypted form. A restored Harbor with a different `secretKey` reads the rows fine but cannot decrypt the passwords, and every replication to that endpoint fails.

The certificate matters because the chart can generate one for you. The Harbor upgrade guide warns that a chart-generated certificate is replaced during an upgrade, and a reinstall does the same. Every client that trusted the old certificate then refuses the new one. That is why this course keeps the certificate in its own Secret and backs that Secret up.

The database and the storage also have a rule between them: take them together. The database lists artifacts by digest, and the storage holds the layers for those digests. A database dump that is newer than the storage copy lists layers the copy does not have. Take the dump and the storage copy one after the other, with no pushes in between; read-only mode, which refuses pushes but allows pulls, is the way to guarantee that on a busy Harbor.

## Take the backups

The playground's Harbor holds one image. Back up all five pieces now. Start with the database: `pg_dump` with `-Fc` writes PostgreSQL's custom format, which `pg_restore` reads and which is compressed.

<!-- astrona:playground:renew -->

```sh
kubectl -n harbor-deps exec deploy/postgres -- pg_dump -U harbor -d registry -Fc -f /backup/registry.dump
kubectl -n harbor-deps exec deploy/postgres -- ls -l /backup
```

The second command lists `registry.dump`. In this course the dump stays in the `postgres` pod's `/backup` folder, which is a separate volume from the database files, so dropping the database does not touch it. A real backup copies the dump off the server, to object storage or a backup system.

Next, copy the image storage. `aws s3 sync` copies every object that is missing or different in the target:

```sh
kubectl -n harbor-deps exec deploy/s3-client -- aws s3 sync s3://harbor s3://harbor-backup
kubectl -n harbor-deps exec deploy/s3-client -- aws s3 ls s3://harbor-backup/docker/registry/v2/
```

The sync prints one line per copied object, and the backup bucket now holds the folders `blobs/` and `repositories/`. A real setup copies to a bucket in another location, often with the store's own replication or versioning.

Then save the two Secrets and the Helm values to files on your machine:

```sh
kubectl -n harbor get secret harbor-tls harbor-secretkey -o yaml > harbor-secrets-backup.yaml
helm -n harbor get values harbor -o yaml > harbor-values-backup.yaml
grep -c 'kind: Secret' harbor-secrets-backup.yaml
```

The count is `2`. The file holds the certificate, its private key and `secretKey` in Base64, which anyone can decode, so a real backup encrypts it and stores it like any other secret. The values file holds no password, because the credentials are in Secrets; back those Secrets up the same way if you cannot recreate them.

## Velero and other tools

Velero is a common Kubernetes backup tool: it saves Kubernetes objects and, with the right plugins, volume snapshots to object storage. It can back up the namespace `harbor`, including the Secrets and the Helm release record. It does not know what is inside an external PostgreSQL or an external bucket, so with external services the database dump and the bucket copy remain your job. Whatever tool you use, the list of five pieces stays the same.

You now have every piece of a Harbor backup: a database dump, a copy of the image storage, the certificate and `secretKey`, and the Helm values. A backup is only proven by a restore, and that is the drill that follows.

## Common pitfalls

> [!WARNING]
> - **Backing up only the database.** The restored Harbor lists images it cannot serve.
> - **Forgetting `secretKey`.** The restore looks fine until Harbor needs a stored password, and then it cannot decrypt it.
> - **Relying on a chart-generated certificate.** A reinstall makes a new one and every client stops trusting Harbor.
> - **Taking the dump and the storage copy hours apart while pushes continue.** They no longer describe the same set of images.
> - **Leaving the backup on the same server.** A dump next to the database it protects is lost with it.
