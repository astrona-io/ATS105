# Summary

A Harbor backup is only proven by a restore. This module named every piece a restore needs and brought a Harbor back after its release, database and image storage were deleted.

## What you learned

A Harbor backup has five pieces. The database holds every project, user, artifact record and policy. The image storage holds the layers and manifests those records point at. The TLS certificate lets clients trust Harbor, and a chart-generated certificate is replaced by an upgrade or a reinstall. `secretKey` encrypts the secrets Harbor stores in its database, such as registry endpoint passwords, so a restored Harbor with a different key cannot decrypt them. The Helm values reproduce the installation.

The database and the storage belong together. A dump that is newer than the storage copy lists layers the copy lacks, so take them one after the other with no pushes in between, using read-only mode on a busy Harbor. `pg_dump -Fc` writes a compressed dump that `pg_restore` reads, and `aws s3 sync` copies the bucket. Velero can back up the Kubernetes objects, but it does not see inside an external database or bucket.

A restore runs in the order Harbor needs: the database first (`createdb`, then `pg_restore`), then the storage, then the Secrets, and Harbor last, so `core` starts on complete data instead of creating empty tables. The proof is the same image with the same digest, pulled completely, without a certificate error. The key facts to remember are these:

- Back up the database, the storage, the certificate, `secretKey` and the values, and keep the copies off the servers they protect.
- Install Harbor only after the database and the storage are back.
- A digest that matches and a full pull that works prove both the records and the bytes.
- Run the drill before you need it.

<!-- astrona:playground:destroy -->
