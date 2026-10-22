# Solution: Finish A Hurried Restore

Work the task yourself first. Running `astrona submit -c sections/section-030/capstone/labs/lab-01` after a step tells you which checks pass, without telling you what is left.

The grader checks four things: Harbor serves the certificate from `harbor-tls`, Harbor uses `harbor-secretkey` and can ping the endpoint `mirror`, `inventory/podinfo:6.15.0` pulls with its original digest, and Harbor is healthy.

## Step 1: Read the values the restore used

```sh
helm -n harbor get values harbor -o yaml > harbor-values.yaml
grep -n -A4 'tls:\|existingSecretSecretKey\|imageChartStorage' harbor-values.yaml
```

Two settings explain two of the symptoms. `expose.tls.certSource` is `auto`, so the chart made a new certificate that the workstation never trusted. And there is no `existingSecretSecretKey`, so Harbor runs with the chart's default `secretKey` and cannot decrypt the stored password of `mirror`.

## Step 2: Find the third fault

```sh
kubectl -n harbor-deps exec deploy/s3-client -- aws s3 ls s3://harbor --recursive | head
kubectl -n harbor-deps exec deploy/s3-client -- aws s3 ls s3://harbor-backup/docker/registry/v2/
```

The bucket `harbor` is empty, while `harbor-backup` holds `blobs/` and `repositories/`. The database was restored, but the image storage was not, so Harbor lists images whose layers it cannot find.

## Step 3: Restore the storage

```sh
kubectl -n harbor-deps exec deploy/s3-client -- aws s3 sync s3://harbor-backup s3://harbor
```

## Step 4: Bring back the certificate and secretKey

Edit `harbor-values.yaml`. Replace the `tls` block under `expose` with:

```yaml
  tls:
    enabled: true
    certSource: secret
    secret:
      secretName: harbor-tls
```

and add this top-level line:

```yaml
existingSecretSecretKey: harbor-secretkey
```

Apply it, and restart the Deployments so every component starts with the original key:

```sh
helm upgrade harbor harbor/harbor --version 1.19.4 --namespace harbor \
  --values harbor-values.yaml --wait --timeout 20m
kubectl -n harbor rollout restart deployment
kubectl -n harbor rollout status deployment/harbor-core --timeout=600s
```

## Step 5: Prove it

```sh
ws() { kubectl -n workstation exec -i deploy/workstation -- "$@"; }
ws regctl registry login harbor.localtest.me:8443 -u admin -p Harbor12345
ws rm -rf /tmp/pull
ws regctl image copy harbor.localtest.me:8443/inventory/podinfo:6.15.0 ocidir:///tmp/pull:6.15.0 && echo "pull ok"
MIRROR_ID="$(ws curl -s -u admin:Harbor12345 'https://harbor.localtest.me:8443/api/v2.0/registries?q=name%3Dmirror' | ws jq -r '.[0].id')"
ws curl -s -o /dev/null -w '%{http_code}\n' -u admin:Harbor12345 -H 'Content-Type: application/json' \
  -d "{\"id\":$MIRROR_ID}" https://harbor.localtest.me:8443/api/v2.0/registries/ping
```

The login works without a certificate error, the pull prints `pull ok`, and the ping answers `200`. Then submit:

```sh
astrona submit -c sections/section-030/capstone/labs/lab-01
```

## Why the obvious shortcuts are wrong

| Shortcut | What happens |
| --- | --- |
| Make the workstation trust the new certificate | Every other client of Harbor still distrusts it; the grader checks the values |
| Retype the `mirror` password in the portal | It works for `mirror`, but every other stored secret is still unreadable with the wrong key |
| Restore the database again | Changes nothing: the database was never the problem |

## Common mistakes

- Upgrading without restarting, so a pod keeps the old key until it restarts on its own.
- Proving the storage with the portal, which only reads the database.
