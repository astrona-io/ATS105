# Certificates For Clients

A client opens a TLS connection to Harbor and decides whether to trust the certificate it receives. If the certificate is wrong, expired or signed by an unknown certificate authority (CA), every login, push and pull fails before Harbor sees a request. This part shows where the chart takes the certificate from, how clients get the CA, and why the choice of source decides what happens at the next upgrade.

## The three certificate sources

The value `expose.tls.certSource` has three settings:

- `auto`: the chart generates a self-signed certificate when it renders the templates.
- `secret`: the chart reads `tls.crt` and `tls.key` from the Kubernetes Secret named in `expose.tls.secret.secretName`. A person or a tool such as cert-manager creates that Secret.
- `none`: the chart configures no certificate on the Ingress. Use it when the ingress controller already has a default certificate.

The playground uses `secret`. Look at the Secret and at the certificate it holds:

<!-- astrona:playground:renew -->

```sh
kubectl -n harbor get secret harbor-tls -o jsonpath='{.data}' | jq 'keys'
kubectl -n harbor get secret harbor-tls -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -subject -issuer -enddate
```

The first command lists three keys: `ca.crt`, `tls.crt` and `tls.key`. The second prints the subject `CN=harbor.localtest.me`, the issuer `CN=Harbor Lab CA` and the date the certificate expires. This needs `openssl` on your own machine. The certificate is signed by the lab CA, not by itself.

## Why `auto` changes on every upgrade

With `auto`, the chart calls a Helm template function that creates a new certificate each time it renders. A `helm upgrade` renders again, so the Secret that the chart owns gets a new certificate. The Harbor upgrade guide warns about this: clients that trusted the old certificate no longer trust the new one.

The fix in the guide is to copy the generated Secret to a name of your own and point `expose.tls.secretName` at it. This course starts from `secret` for that reason: the certificate lives in `harbor-tls` and the chart never replaces it. The same rule matters for restores, because a restored Harbor must present the same certificate as before.

## Publishing the CA with `caSecretName`

Clients need the CA that signed the certificate. The value `caSecretName` names a Secret with a `ca.crt` key; the `core` component mounts it and serves it at the API path `/api/v2.0/systeminfo/getcert`. The `harbor` command-line tool and the portal use that path to offer the CA to users. Fetch it and compare it with the CA in the Secret:

```sh
ws() { kubectl -n workstation exec -i deploy/workstation -- "$@"; }
ws curl -s https://harbor.localtest.me:8443/api/v2.0/systeminfo/getcert | head -2
```

The answer starts with `-----BEGIN CERTIFICATE-----`. If `caSecretName` is empty, the path has nothing to serve.

## Replacing a certificate

To renew a certificate, you create a new certificate and key, update the Secret `harbor-tls` and make `nginx` read it. Kubernetes updates a mounted Secret file after a short delay, but `nginx` loads certificates only when it starts or reloads. The reliable step is to restart the proxy:

```sh
kubectl -n harbor rollout restart deployment/harbor-nginx
kubectl -n harbor rollout status deployment/harbor-nginx
```

Clients that trust the CA keep working if the new certificate comes from the same CA. If the CA changes, every client must receive the new CA first. The workstation in this course reads the CA once, when its pod starts, so a changed CA breaks its tools until the pod restarts.

You now know the three sources, the reason `auto` is risky, and how a certificate is replaced. All of this protects the connection between a client and `nginx`. Behind `nginx`, the components still talk to each other in plain HTTP, which is the next topic.

## Common pitfalls

> [!WARNING]
> - **Using `auto` and then distributing the certificate.** The next upgrade replaces it.
> - **Updating the Secret and not restarting `nginx`.** The old certificate stays in use.
> - **Changing the CA without telling clients.** Every client fails with a certificate error.
> - **A certificate without the name in `externalURL`.** The certificate must list the host name that clients use in its subject alternative names.
> - **Forgetting `caSecretName`.** Harbor cannot serve its CA.
