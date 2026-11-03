# Proxies, Large Pushes And Update Strategy

Three smaller settings decide whether Harbor works in a company network and whether an upgrade interrupts it: the proxy that Harbor uses to reach the outside, the limits of the ingress in front of it, and the way Kubernetes replaces pods. Each one produces errors that look unrelated to the setting that causes them. This part explains all three.

## Harbor's own outbound proxy

Harbor sometimes makes requests to other servers: replication to another registry, a webhook, the Trivy database download. In a network that forces outbound traffic through a proxy, these requests fail unless Harbor knows the proxy. The chart has a `proxy` block:

| Field | What it sets |
| --- | --- |
| `httpProxy`, `httpsProxy` | The proxy URL for HTTP and HTTPS requests |
| `noProxy` | Hosts that bypass the proxy; the default is `127.0.0.1,localhost,.local,.internal` |
| `components` | Which components use the proxy; the default is `core`, `jobservice` and `trivy` |

The block affects only requests that Harbor makes, not requests that clients make to Harbor. A common mistake is to leave out the cluster's own names from `noProxy`. Harbor then sends requests to `harbor-registry` or to the external PostgreSQL service through the proxy, and they fail. Add `.svc` and `.cluster.local` when a proxy is set.

Check what the playground sets:

<!-- astrona:playground:renew -->

```sh
helm -n harbor get values harbor -o yaml | grep -A6 '^proxy:' || echo "no proxy values set"
kubectl -n harbor get configmap harbor-core -o jsonpath='{.data}' | jq -r 'to_entries[] | select(.key | test("PROXY")) | "\(.key)=\(.value)"'
```

The first command prints `no proxy values set`. The second prints the proxy variables that `core` receives, which carry the chart defaults for `NO_PROXY`.

## The ingress in front of Harbor

When `expose.type` is `ingress`, an ingress controller sits in front of `nginx`. Its limits apply to every push. The chart's default annotations set `proxy-body-size: "0"`, which means no limit on the request body. Without it, an ingress controller based on NGINX refuses an upload larger than its own default and returns `413 Request Entity Too Large`. Image layers are often hundreds of megabytes, so this annotation is required. Different ingress controllers use different annotation names; the chart's comment says an Envoy-based controller needs `ingress.kubernetes.io/force-ssl-redirect: "true"` instead of the NGINX lines.

Timeouts are the second limit. A slow upload of a large layer can exceed an ingress's read timeout and fail halfway. The symptom is a push that stops at the same percentage each time. Raise the timeout annotation your controller documents, and keep it larger than the longest expected upload.

## The update strategy

The value `updateStrategy.type` sets how Kubernetes replaces pods of the Deployments the chart creates. The default is `RollingUpdate`: a new pod starts, becomes ready, and only then does an old pod stop. With more than one replica this keeps Harbor available during an upgrade. The other choice, `Recreate`, stops all old pods first. Use it only when two versions must never run together, for example when a component keeps a `ReadWriteOnce` volume and a new pod on another node could not mount it.

Read the strategy from a live Deployment:

```sh
kubectl -n harbor get deployment harbor-core -o jsonpath='{.spec.strategy}{"\n"}'
```

The answer shows type `RollingUpdate` with its default surge and unavailable limits. A rolling update only protects you if the pods become ready quickly and correctly, which depends on the probes covered in a later module.

You now know how Harbor's outbound proxy, the ingress limits and the update strategy shape the behavior around the edges of the chart. These settings rarely appear in a first installation, and they cause many of the surprises in a second one.

## Common pitfalls

> [!WARNING]
> - **Setting a proxy without `noProxy` for cluster names.** Internal calls go through the proxy and fail.
> - **Expecting the `proxy` block to affect clients.** It affects only requests that Harbor makes.
> - **Pushing large layers through an ingress with a body-size limit.** The client sees `413`.
> - **Using `Recreate` with several replicas.** Harbor is down during every upgrade.
> - **Copying NGINX ingress annotations to another controller.** The names differ.
