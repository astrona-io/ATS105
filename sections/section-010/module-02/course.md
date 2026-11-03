# Expose Harbor And Secure Its Traffic

A client that pushes an image does not talk to Harbor's registry directly. The request enters through one address, passes the `nginx` proxy, and is sent on to `core` or `registry` depending on the path. If that address, its certificate or the traffic behind it is wrong, nothing works, and the error often appears in a Docker client far away from the cause.

Keep one sentence in mind: **the address in `externalURL` is the address Harbor tells every client to use.** Harbor builds the token URL, the login hints and every redirect from it. This module covers how the chart exposes that address, where the certificate comes from, how to encrypt the traffic between Harbor's own components, and the settings that matter when pushes are large or the cluster sits behind a proxy.

The module has four parts. **How Harbor Is Exposed** compares the five `expose.type` values and shows what `externalURL` changes. **Certificates For Clients** covers `certSource`, the CA Secret and how a certificate is replaced. **Encrypting Traffic Between Components** turns on internal TLS. **Proxies, Large Pushes And Update Strategy** covers the proxy settings, ingress annotations and how Kubernetes replaces pods during an upgrade. A graded lab follows the third part.

## Learning objectives

After this module you can:

- Choose between `ingress`, `clusterIP`, `nodePort`, `loadBalancer` and `route` and set the matching values.
- Explain what `externalURL` controls and what breaks when it is wrong.
- Provide the certificate from a Secret and publish the CA with `caSecretName`.
- Explain why a certificate that the chart generates changes on every upgrade.
- Turn on internal TLS and say which connections it encrypts.
- Set the proxy values, the ingress body-size annotation and the update strategy.

## Before you start

You need Kubernetes basics (Services, Ingress, Secrets) and the ability to read a Helm values file. You should know what a certificate, a certificate authority (CA) and a private key are.

Your playground is a single-node `kind` cluster. **Harbor 2.15.4** runs there as the Helm release `harbor` in the namespace `harbor`, installed with chart 1.19.4 on the external PostgreSQL, Redis and S3 bucket in the namespace `harbor-deps`. It answers at `https://harbor.localtest.me:8443` with the certificate in the Secret `harbor-tls`, which a lab certificate authority signed. The project `inventory` holds `inventory/podinfo:6.15.0`. The `workstation` pod in the namespace `workstation` holds `regctl`, `curl` and `jq` and trusts that certificate authority. The administrator is `admin` with the password `Harbor12345`; these are lab-only credentials.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->
