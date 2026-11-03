# Summary

Every client reaches Harbor through one address and one proxy. The `nginx` proxy sends API and token paths to `core`, registry paths to `registry` and everything else to `portal`. The value `expose.type` chooses how Kubernetes publishes the proxy: `ingress`, `clusterIP`, `nodePort`, `loadBalancer` or a Gateway API `route`. The value `externalURL` is what Harbor tells clients: it builds the token realm and the login commands, so it must be the real public address with its port.

The certificate comes from `expose.tls.certSource`. With `auto`, the chart generates a new certificate on every render, so an upgrade replaces it. With `secret`, the certificate stays in a Secret that the chart does not change. The value `caSecretName` lets `core` serve the signing CA to clients. A replaced certificate is read by `nginx` only after a restart.

Internal TLS encrypts the connections between Harbor's own components. With `internalTLS.enabled: true`, the components listen on port `8443` instead of `8080`, and the chart creates one Secret per component when the source is `auto`. Changing it restarts every component.

At the edges, the `proxy` block controls requests that Harbor makes to the outside and needs the cluster names in `noProxy`. An ingress needs a body-size limit of zero and a long enough timeout for large layers. `RollingUpdate` keeps Harbor available during upgrades when there is more than one replica.

Key facts to remember:

- `externalURL` must match the address clients use, including the port.
- Use `certSource: secret` so that an upgrade never replaces the certificate.
- Start every `helm upgrade` from `helm get values`.

<!-- astrona:playground:destroy -->
