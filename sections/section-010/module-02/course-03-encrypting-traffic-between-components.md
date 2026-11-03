# Encrypting Traffic Between Components

TLS at the front door protects the path from the client to `nginx`. Behind it, `nginx`, `core`, `registry`, `registryctl`, `portal`, `jobservice` and the Trivy adapter talk over plain HTTP inside the cluster. On a shared cluster, or under a security rule that demands encryption in transit, that is not acceptable. This part turns on internal TLS and shows what changes.

## What internal TLS does

Internal TLS makes each Harbor component serve HTTPS and makes its callers check the certificate. The Harbor installation guide describes it as available since Harbor 2.0. In the chart, the block `internalTLS` controls it:

| Field | What it sets |
| --- | --- |
| `enabled` | Turns internal TLS on; the default is `false` |
| `certSource` | `auto` generates the certificates, `manual` takes them from values, `secret` reads one Secret per component |
| `trustCa` | The CA certificate text; only used with `manual` |
| `strong_ssl_ciphers` | Restricts the cipher list when `true` |
| `core`, `jobservice`, `registry`, `portal`, `trivy` | Per component: `secretName` for `secret`, or `crt` and `key` for `manual` |

The Harbor guide adds two rules for certificates you provide: one CA must sign all of them, and each certificate needs a subject alternative name that equals the component name. With `auto`, the chart handles both.

## See the plain HTTP first

Before you change anything, look at the port that `core` listens on and at its Service:

<!-- astrona:playground:renew -->

```sh
kubectl -n harbor get configmap harbor-core -o jsonpath='{.data.PORT}{"\n"}'
kubectl -n harbor get service harbor-core -o jsonpath='{.spec.ports[*].name}{"\n"}'
```

The port is `8080` and the Service port is named `http-web`. Those names change when internal TLS is on.

## Turn it on

A `helm upgrade` replaces the values you passed before, so start from the installed values. Save them, then add the block:

```sh
helm -n harbor get values harbor -o yaml > harbor-values.yaml
```

Add these lines at the end of `harbor-values.yaml`:

```yaml
internalTLS:
  enabled: true
  certSource: auto
```

Apply it:

```sh
helm upgrade harbor harbor/harbor --version 1.19.4 --namespace harbor \
  --values harbor-values.yaml --wait --timeout 20m
```

Then check the result:

```sh
kubectl -n harbor get configmap harbor-core -o jsonpath='{.data.PORT}{"\n"}'
kubectl -n harbor get secrets | grep internal-tls
```

The port is now `8443`. The chart created one Secret per component whose name ends in `-internal-tls`, such as `harbor-core-internal-tls`. Every component restarted because its pod template changed. Harbor's health endpoint should report `healthy` again once they are ready, and a push and pull through `https://harbor.localtest.me:8443` work as before. Clients see no difference: the public certificate is still the one in `harbor-tls`.

## What it costs

Every internal connection now needs a TLS handshake, so CPU use rises slightly. With `auto`, the internal certificates are generated at render time, so they change on each upgrade and the pods restart. With `secret`, you control the lifetime and rotate the Secrets yourself. Turning internal TLS on or off restarts the whole stack, so schedule it like any other upgrade.

You now know that internal TLS encrypts the connections between components, that the chart switches the component ports from `8080` to `8443`, and that `secret` gives stable certificates. What remains in this module are the settings around the edges: proxies, large uploads and how pods are replaced.

## Common pitfalls

> [!WARNING]
> - **Forgetting that `helm upgrade` replaces values.** Start from `helm get values`.
> - **Using `manual` with certificates from different CAs.** One CA must sign them all.
> - **Certificates without a subject alternative name.** The components refuse to start or connect.
> - **Reading "TLS is on" as "the front door is secure".** The public certificate is a separate setting.
> - **Changing internal TLS during working hours.** Every pod restarts.

## Your mission: Enable Internal TLS Between Harbor Components

You can now enable internal TLS and check that the components moved to port `8443`. The graded lab gives you a Harbor with plain HTTP between components and asks you to turn on internal TLS without breaking pushes and pulls.

The lab runs in its own cluster, so first pause your playground. Nothing in it is lost:

```sh
astrona stop ats-105-playground-010-02
```

Then start the lab:

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS105.git -c sections/section-010/module-02/labs/lab-01
```

The task is on the next page. Solve it on your own first. When you think you are done, send it for grading:

```sh
astrona submit -c sections/section-010/module-02/labs/lab-01
```

When the lab is done, remove it and start your playground again:

```sh
astrona destroy ats-105-lab-010-02
astrona start ats-105-playground-010-02
```
