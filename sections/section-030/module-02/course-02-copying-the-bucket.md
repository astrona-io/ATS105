# Copying The Bucket

The registry stores every layer and manifest as an object in the S3 bucket `harbor`. A restored database that points to objects that do not exist gives a Harbor that lists images and cannot pull them. This part copies the bucket and proves that the copy is complete.

## Sync the bucket

`aws s3 sync` copies the objects that are missing or different in the destination. It does not delete anything in the destination unless you add `--delete`. The `s3-client` pod holds the AWS command-line tool and the credentials for the S3 service in the playground. Define a helper and copy the bucket:

<!-- astrona:playground:renew -->

```sh
s3() { kubectl -n harbor-deps exec -i deploy/s3-client -- aws s3 "$@"; }
s3 sync s3://harbor s3://harbor-backup
```

The command prints one line per object copied. Run it a second time and it prints nothing, because nothing is missing.

## Compare the counts

A copy that ends without an error can still be incomplete, for example when the command was interrupted. Count the objects on both sides:

```sh
s3 ls s3://harbor --recursive | wc -l
s3 ls s3://harbor-backup --recursive | wc -l
```

The two numbers are the same. Compare the sizes too with `s3 ls s3://harbor --recursive --summarize`, whose last lines give the total number of objects and the total size.

## Order and consistency

The database and the bucket are copied at different moments. If someone pushes an image between the two copies, the database may know a tag whose layers are not yet in the bucket copy, or the bucket may hold layers that no record names. The second case is harmless, because garbage collection removes unreferenced blobs. The first case breaks a pull after a restore. Two habits reduce the risk: copy the bucket after the dump, and put Harbor in read-only mode for the duration of the backup when the window allows it.

You now know how to copy the bucket and how to prove the copy by counting objects. The data of the registry is now safe, but a restored Harbor also needs the certificate and the encryption key, which live in Secrets.

## Common pitfalls

> [!WARNING]
> - **Using `--delete` on the wrong side.** `sync --delete` removes objects from the destination that the source does not have.
> - **Trusting a silent `sync`.** Compare the object counts.
> - **Copying the bucket before the dump.** A tag in the dump can then point to layers that are not in the copy.
> - **Keeping the copy in the same S3 service as the original.** A failure of the service loses both.
