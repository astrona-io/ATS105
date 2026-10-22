# Upgrading The Chart

Harbor releases patch versions every few weeks, and each one fixes bugs and security problems. Staying current is not optional for a registry, but each upgrade starts new Harbor code on your existing database. This part follows the Harbor upgrade guide for Helm on the playground, from 2.15.2 to 2.15.4, and explains the one rule that makes it safe.

## The upgrade guide in four steps

The Harbor guide for upgrading a Helm installation has four steps:

1. **Back up the database**, in case the upgrade fails.
2. **Get the new chart.**
3. **Configure the new chart** with the same values as the old one.
4. **Run `helm upgrade`.**

The guide also gives the reason for step 1. When a newer Harbor starts, it may change the database schema, the layout of the tables, to what the new code expects. That change only goes forward. So the guide says plainly that `helm rollback` is not supported: rolling back puts the old pods on a schema they do not understand. If an upgrade goes wrong, the way back is to restore the database backup and install the old chart again.

The guide has one warning for step 3. If the chart generated Harbor's TLS certificate, the upgrade generates a new one and overwrites the old one, and every client that trusted the old certificate stops working. The guide's fix is to copy the generated certificate into a Secret of your own and point `expose.tls.secret.secretName` at it. The playground already does this: its certificate comes from the Secret `harbor-tls`.

## Check what you have

Start with the version that runs now. Harbor reports it in `/api/v2.0/systeminfo`, and Helm reports the chart:

<!-- astrona:playground:renew -->

```sh
ws() { kubectl -n workstation exec -i deploy/workstation -- "$@"; }
helm -n harbor list
ws curl -s -u admin:Harbor12345 https://harbor.localtest.me:8443/api/v2.0/systeminfo | ws jq -r '.harbor_version'
```

Helm lists the release `harbor` with the chart `harbor-1.19.2` and the app version `2.15.2`. Harbor reports a version string that starts with `v2.15.2`.

Then look at what the new chart changes. `helm show values` prints a chart's default values, so comparing the two versions shows every default that moved:

```sh
helm repo update harbor
helm search repo harbor/harbor --versions | head -5
diff <(helm show values harbor/harbor --version 1.19.2) <(helm show values harbor/harbor --version 1.19.4)
```

The search lists 1.19.4 with the app version 2.15.4. Between two patch releases of the chart, most of the difference is the image tags moving from `v2.15.2` to `v2.15.4`. Read every other line: a changed default you do not set yourself changes your Harbor too.

## Back up, then upgrade

Take the database backup the guide asks for. `pg_dump -Fc` writes a compressed dump that `pg_restore` can read:

```sh
kubectl -n harbor-deps exec deploy/postgres -- pg_dump -U harbor -d registry -Fc -f /backup/before-upgrade.dump
kubectl -n harbor-deps exec deploy/postgres -- ls -l /backup
```

The folder now holds `before-upgrade.dump`. Now upgrade with the same values the release uses, saved straight from Helm:

```sh
helm -n harbor get values harbor -o yaml > harbor-values.yaml
helm upgrade harbor harbor/harbor --version 1.19.4 --namespace harbor \
  --values harbor-values.yaml --wait --timeout 20m
```

Then check the result:

```sh
helm -n harbor list
ws curl -s -u admin:Harbor12345 https://harbor.localtest.me:8443/api/v2.0/systeminfo | ws jq -r '.harbor_version'
ws curl -s https://harbor.localtest.me:8443/api/v2.0/health | ws jq -r '.status'
```

Helm shows `harbor-1.19.4` and `2.15.4`, Harbor reports a version that starts with `v2.15.4`, and the health status is `healthy`. The `workstation` pod reached Harbor without a certificate error, because the certificate came from `harbor-tls` and did not change.

A patch upgrade within 2.15 is the gentle case. A minor upgrade, from 2.14 to 2.15 for example, is more likely to change the schema, and the release notes of each version say what else to check. The steps stay the same.

You now know how to upgrade Harbor safely: back up the database, compare the defaults, keep the values and the certificate, upgrade, and check the version and the health. The open question is the harder change: moving the database itself to another server.

## Common pitfalls

> [!WARNING]
> - **Planning on `helm rollback`.** The schema only migrates forward. The way back is a database restore plus the old chart.
> - **Upgrading without the old values.** The new chart falls back to its defaults for everything you did not pass.
> - **Relying on a chart-generated certificate.** The upgrade replaces it. Keep the certificate in your own Secret.
> - **Skipping the diff of defaults.** A default that changed between versions changes your Harbor without a line in your values.
