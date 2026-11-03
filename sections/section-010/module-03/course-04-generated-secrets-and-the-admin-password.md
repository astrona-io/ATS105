# Generated Secrets And The Admin Password

When you set nothing, the chart creates the shared secrets itself and sets the administrator password from a value in `values.yaml`. Both behaviours have surprises. The generated secrets survive an upgrade only when the chart can look up the old ones. The administrator password is applied once, at the first start, and later changes to the value do nothing. This part explains both, so that you do not meet them for the first time during an incident.

## What the chart generates

The chart creates a Secret for each component: `harbor-core`, `harbor-jobservice` and `harbor-registry`. They hold random values that the components use to trust each other: `secret` for `core`, `JOBSERVICE_SECRET` for `jobservice`, `REGISTRY_HTTP_SECRET` for `registry`, and `CSRF_KEY` for the web session protection. List them and their key names:

<!-- astrona:playground:renew -->

```sh
for name in harbor-core harbor-jobservice harbor-registry; do
  echo "$name: $(kubectl -n harbor get secret $name -o jsonpath='{.data}' | jq -r 'keys | join(", ")')"
done
```

Each line shows the Secret name and its keys, for example `CSRF_KEY` and `secret` for `harbor-core`. The values are not printed.

## How an upgrade keeps them

On a new render, the chart asks the cluster for the existing Secret with the Helm `lookup` function and reuses the old value. That is why an ordinary `helm upgrade` does not change the generated secrets. The same function returns nothing when Helm only renders templates without a cluster, for example with `helm template`, or in a GitOps tool that renders the chart outside the cluster. In that case the chart generates new random values every time. The result is a new value at each deployment and restarts of the pods that read them.

There are two safe ways out. Set the values yourself in Secrets that you own, using `core.existingSecret`, `jobservice.existingSecret` and `registry.existingSecret`, so that nothing is generated. Or render with a tool that can reach the cluster. The first one is the choice for production, because it also gives you the values for a backup.

## The administrator password

`harborAdminPassword` has the default `Harbor12345`. Harbor reads it exactly once: when `core` starts on an empty database, it creates the user `admin` with that password. After that, the password lives in the database. Changing the value and upgrading changes the environment variable of the pod and nothing else. Test it:

```sh
helm -n harbor get values harbor -o yaml > harbor-values.yaml
sed -i.bak 's/^harborAdminPassword: .*/harborAdminPassword: Changed12345/' harbor-values.yaml
helm upgrade harbor harbor/harbor --version 1.19.4 --namespace harbor --values harbor-values.yaml --wait --timeout 20m
ws() { kubectl -n workstation exec -i deploy/workstation -- "$@"; }
ws curl -s -o /dev/null -w '%{http_code}\n' -u admin:Harbor12345 https://harbor.localtest.me:8443/api/v2.0/users/current
ws curl -s -o /dev/null -w '%{http_code}\n' -u admin:Changed12345 https://harbor.localtest.me:8443/api/v2.0/users/current
```

The old password still works, so the first call prints `200`, and the new one is refused with `401`. If the line `harborAdminPassword` is missing from the file, the playground used a different way to set it; add the line before you run the upgrade. To change the password of a running Harbor, use the portal or the API call `PUT /users/{user_id}/password` with the fields `old_password` and `new_password`. The value `existingSecretAdminPassword` follows the same rule: it names where the first password comes from, nothing more.

You now know what the chart generates, why a render without cluster access creates new values each time, and why the administrator password cannot be changed through the chart. With this you have the full picture of Harbor's credentials: where each one lives, how it reaches a pod and how to change it.

## Common pitfalls

> [!WARNING]
> - **Rendering with `helm template` and applying the result.** Without `lookup`, the generated secrets change on every deploy.
> - **Changing `harborAdminPassword` to change the password.** Harbor ignores it after the first start.
> - **Leaving `Harbor12345` in a real installation.** Change the password in the portal right after the first login.
> - **Using `existingSecretAdminPassword` with the wrong key name.** The default key is `HARBOR_ADMIN_PASSWORD`.
> - **Losing the generated Secrets.** They are not in Git; back them up with the database.
