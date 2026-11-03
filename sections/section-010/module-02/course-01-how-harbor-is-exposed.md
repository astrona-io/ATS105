# How Harbor Is Exposed

Before Harbor can store anything, clients must be able to reach it, and they must all reach it the same way. The chart has one setting that chooses how the cluster publishes Harbor and one setting that tells Harbor its own public address. This part shows both on the running playground, so that you can read them on any other Harbor.

## The path of a request

Every client request enters Harbor through the `nginx` proxy (the Deployment `harbor-nginx`). The proxy sends the paths `/api/`, `/service/` and `/c/` to `core`, the path `/v2/` to `registry`, and everything else to `portal`. Because one proxy owns the public address, `core`, `registry` and `portal` stay private Services inside the cluster.

The value `expose.type` decides how traffic reaches that proxy. Look at what the playground uses:

<!-- astrona:playground:renew -->

```sh
helm -n harbor get values harbor -o yaml | grep -A12 '^expose:'
kubectl -n harbor get services,deployments
```

The values show `type: clusterIP`, the TLS settings and the port numbers `8080` and `8443`. The Services list holds one Service named `harbor` of type `ClusterIP`, which is the proxy's entry point, and the internal Services of `core`, `registry`, `portal` and `jobservice`. The Deployments include `harbor-nginx`.

## The five expose types

The chart supports five ways to publish the proxy. Each one needs its own block under `expose`:

| `expose.type` | What the chart creates | When to use it |
| --- | --- | --- |
| `ingress` | An Ingress that routes `expose.ingress.hosts.core` to the proxy | A cluster with an ingress controller; the default |
| `clusterIP` | A Service of type `ClusterIP` with the ports `expose.clusterIP.ports` | Another component (a gateway, a port-forward) provides the public address |
| `nodePort` | A Service of type `NodePort` on the ports `30002` (HTTP) and `30003` (HTTPS) by default | A test cluster without a load balancer |
| `loadBalancer` | A Service of type `LoadBalancer`, optionally with a fixed `IP` and `sourceRanges` | A cloud cluster that provisions load balancers |
| `route` | A Gateway API `HTTPRoute` that attaches to the gateways in `parentRefs` for the `hosts` you list | A cluster that uses the Gateway API |

This course uses `clusterIP` because the playground reaches Harbor through a port-forward and a CoreDNS rewrite. On a production cluster you would normally use `ingress`, `loadBalancer` or `route`. In every case Harbor has exactly one public address.

When the type is not `ingress`, the chart needs a name for the certificate. The value `expose.tls.auto.commonName` sets the common name of a generated certificate; it is required for the types other than `ingress`.

## What `externalURL` controls

The value `externalURL` has the form `protocol://domain[:port]`. It must be the address that clients really use, including the port when it is not the default. It does not change how Kubernetes publishes Harbor. It changes what Harbor tells clients. Ask the playground's Harbor how it answers an unauthenticated request to the registry path:

```sh
ws() { kubectl -n workstation exec -i deploy/workstation -- "$@"; }
ws curl -sI https://harbor.localtest.me:8443/v2/
```

The status is `401 Unauthorized`, and the `Www-Authenticate` header names the realm `https://harbor.localtest.me:8443/service/token`. That realm is built from `externalURL`. A Docker or `regctl` client reads it and requests a token from exactly that address.

Now suppose `externalURL` said `https://core.harbor.domain`, the chart's default. Harbor would still answer on the port-forward, but every client would be told to fetch its token from `core.harbor.domain`. Logins would fail with a name resolution or certificate error that mentions an address the user never typed. The same value fills the `docker login` and `docker push` commands that the portal shows. If Harbor sits behind another proxy or load balancer, `externalURL` must be the address of that outer proxy, not of the Service.

The URL must be a domain root. The Harbor guide says the chart does not support running Harbor under a path such as `/harbor`.

## Check what Harbor reports about itself

Harbor's own API reports the values it uses:

```sh
ws curl -s https://harbor.localtest.me:8443/api/v2.0/systeminfo | ws jq '{harbor_version, external_url}'
```

The answer holds the Harbor version `v2.15.4` and the external URL. When a login misbehaves, comparing this value with the address in the failing command is the fastest first check.

You now know that one proxy owns Harbor's address, that `expose.type` picks how Kubernetes publishes it and that `externalURL` is what clients are told. The address is only half of the setup, because a client also decides whether it trusts the certificate that the proxy presents. That is the next question.

## Common pitfalls

> [!WARNING]
> - **Leaving `externalURL` at the chart default.** Clients receive a token URL that does not exist.
> - **Leaving out the port.** An address on a non-default port needs the port in `externalURL`, or the token URL points to the wrong port.
> - **Putting Harbor under a path.** The chart supports a domain root only.
> - **Using `nodePort` with the node's internal address.** `externalURL` must be an address that clients can reach.
> - **Setting `expose.type` without filling its block.** The values of the other types are ignored.
