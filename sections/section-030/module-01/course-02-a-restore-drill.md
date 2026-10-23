# A Restore Drill

The only way to know a backup works is to restore it, on purpose, before you need to. This part runs a full drill on the playground: it deletes Harbor's release, its database and its image storage, restores all of them from the backups, and proves the result with the original digest of an image.

## Record what must come back

A restore is proven by data that is the same before and after. Record the digest of the image, which identifies its content exactly, and check that the backups from your earlier steps exist. The helper `ws` runs a command in the `workstation` pod.

<!-- astrona:playground:renew -->

```sh
ws() { kubectl -n workstation exec -i deploy/workstation -- "$@"; }
ws regctl registry login harbor.localtest.me:8443 -u admin -p Harbor12345
ORIGINAL_DIGEST="$(ws regctl image digest harbor.localtest.me:8443/inventory/podinfo:6.15.0)"
echo "$ORIGINAL_DIGEST"
kubectl -n harbor-deps exec deploy/postgres -- ls -l /backup/registry.dump
ls harbor-secrets-backup.yaml harbor-values-backup.yaml
```

The digest starts with `sha256:`. If the dump or one of the two files is missing, take the backups again before you go on: the next step deletes the originals.

## The disaster

These three commands delete the Harbor release, drop the database and empty the image bucket. `dropdb` must connect to a different database than the one it drops, so `--maintenance-db=postgres` makes it connect to `postgres`:

```sh
helm -n harbor uninstall harbor --wait
kubectl -n harbor-deps exec deploy/postgres -- dropdb -U harbor --maintenance-db=postgres registry
kubectl -n harbor-deps exec deploy/s3-client -- aws s3 rm s3://harbor --recursive
```

Harbor's pods are gone, the database `registry` no longer exists, and the bucket `harbor` is empty. The Secrets in the namespace `harbor` survive `helm uninstall`, because the chart did not create them; on a real lost cluster they would be gone too, which is why you saved them to a file.

## The restore

Restore in the order Harbor needs: first the data, then the secrets, and Harbor last, so it starts on complete data. Recreate the empty database and restore the dump into it:

```sh
kubectl -n harbor-deps exec deploy/postgres -- createdb -U harbor --maintenance-db=postgres registry
kubectl -n harbor-deps exec deploy/postgres -- pg_restore -U harbor -d registry /backup/registry.dump
```

`pg_restore` prints nothing when it succeeds. Then copy the image storage back:

```sh
kubectl -n harbor-deps exec deploy/s3-client -- aws s3 sync s3://harbor-backup s3://harbor
```

Now put back the Secrets and install Harbor with the saved values. `kubectl apply` recreates any Secret that is missing and leaves an identical one as it is:

```sh
kubectl apply -f harbor-secrets-backup.yaml
helm install harbor harbor/harbor --version 1.19.4 --namespace harbor \
  --values harbor-values-backup.yaml --wait --timeout 20m
```

Harbor starts on the restored database. Its `core` component finds Harbor's tables already in place and starts serving them.

## Prove the restore

The proof is the same image with the same digest, pulled completely:

```sh
RESTORED_DIGEST="$(ws regctl image digest harbor.localtest.me:8443/inventory/podinfo:6.15.0)"
[ "$RESTORED_DIGEST" = "$ORIGINAL_DIGEST" ] && echo "same digest"
ws rm -rf /tmp/pull
ws regctl image copy harbor.localtest.me:8443/inventory/podinfo:6.15.0 ocidir:///tmp/pull:6.15.0 && echo "pull ok"
```

The first check prints `same digest`: the database knows the image. The pull prints `pull ok`: the storage holds every layer. And it worked without a certificate error, because Harbor came back with the same certificate the `workstation` pod trusted before the disaster.

You have now restored Harbor from nothing but backups: the database from a dump, the images from a bucket copy, the certificate and `secretKey` from saved Secrets, and the installation from saved values. What remains is to run the same drill on a Harbor you did not prepare.

## Common pitfalls

> [!WARNING]
> - **Installing Harbor before the database is restored.** Harbor creates fresh tables, and `pg_restore` then collides with them.
> - **Proving the restore with the portal.** The portal shows the database. Pull the whole image to prove the storage.
> - **Restoring with new Secrets.** A new certificate breaks every client; a new `secretKey` breaks every stored password.
> - **Never running the drill.** The first restore you run should not be the one during an outage.

## Your mission: Back Up Harbor And Restore It After A Disaster

You can now back up every piece of Harbor and restore it after a disaster. The graded lab gives you a Harbor with one image and asks you to back it up, run the disaster from the task, and restore Harbor so the image comes back with its original digest.

The lab runs in its own cluster, so first pause your playground. Nothing in it is lost:

```sh
astrona stop ats-105-playground-030-01
```

Then start the lab:

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS105.git -c sections/section-030/module-01/labs/lab-01
```

The task is on the next page. Solve it on your own first. When you think you are done, send it for grading:

```sh
astrona submit -c sections/section-030/module-01/labs/lab-01
```

When the lab is done, remove it and start your playground again:

```sh
astrona destroy ats-105-lab-030-01
astrona start ats-105-playground-030-01
```
