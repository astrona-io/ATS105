# Solution: Enable Internal TLS Between Harbor Components

Work the task yourself first. Running `astrona submit -c sections/section-010/module-02/labs/lab-01` after a step tells you which checks pass, without telling you what is left.

The grader checks four things: the four internal certificate Secrets and port `8443` on `core`, the external settings in the Helm values, a healthy Harbor, and a push and pull that work, including the image that existed before.

## Step 1: Start from the installed values

```sh
helm -n harbor get values harbor -o yaml > harbor-values.yaml
grep -n 'internalTLS' harbor-values.yaml || echo "internalTLS not set"
kubectl -n harbor get configmap harbor-core -o jsonpath='{.data.PORT}{"\n"}'
```

The file has no `internalTLS` block, and `core` listens on port `8080`.

## Step 2: Add the block

Add these lines at the end of `harbor-values.yaml`:

```yaml
internalTLS:
  enabled: true
  certSource: auto
```

## Step 3: Upgrade

Apply it:

```sh
helm upgrade harbor harbor/harbor --version 1.19.4 --namespace harbor \
  --values harbor-values.yaml --wait --timeout 20m
```

Then check the result:

```sh
kubectl -n harbor get configmap harbor-core -o jsonpath='{.data.PORT}{"\n"}'
kubectl -n harbor get secrets | grep internal-tls
ws() { kubectl -n workstation exec -i deploy/workstation -- "$@"; }
ws curl -s https://harbor.localtest.me:8443/api/v2.0/health | ws jq -r '.status'
```

The port is `8443`, the four Secrets exist, and the status is `healthy` once the pods have restarted.

## Step 4: Prove it before the grader does

```sh
ws regctl registry login harbor.localtest.me:8443 -u admin -p Harbor12345
ws rm -rf /tmp/pull
ws regctl image copy harbor.localtest.me:8443/inventory/podinfo:6.15.0 ocidir:///tmp/pull:6.15.0 && echo "pull ok"
```

The pull prints `pull ok`. Then submit:

```sh
astrona submit -c sections/section-010/module-02/labs/lab-01
```

## Why the obvious shortcuts are wrong

| Shortcut | What happens |
| --- | --- |
| Upgrade with a file that holds only `internalTLS` | Helm replaces the user values, so the external services and the certificate settings disappear |
| Edit the `harbor-core` ConfigMap by hand | The next `helm upgrade` overwrites it and the other components still use HTTP |

## Common mistakes

- Checking health too early. Every component restarts, so wait for `helm upgrade --wait` to finish.
- Reading a healthy status as proof of port `8443`. Check the ConfigMap too.
