# Back Up And Restore Harbor — Playground

- **ID:** PLAYGROUND
- **Slug:** ats-105-playground-030-01
- **Author:** Paris Nakita Kejser
- **Type:** Astrona playground — clean environment, no task, no grading

Harbor (chart 1.19.4) on `kind`, with PostgreSQL, Redis and an
S3-compatible store in the namespace `harbor-deps` and the `workstation` pod.
Nothing to submit.

## Run it

```sh
astrona run -c .
astrona destroy ats-105-playground-030-01
```

`astrona destroy` takes the environment name (`metadata.name` = `ats-105-playground-030-01`), not
the config path.

## Layout

| Path | Purpose |
| --- | --- |
| `config.yaml` | Environment definition |
| `bootstrap/prepare.sh` | Helm, external services, Harbor, workstation, starting state (generated) |
| `manifests/harbor-deps.yaml` | PostgreSQL, Redis, S3 store and client (generated) |
| `manifests/harbor-values.yaml` | Helm values for Harbor (generated) |
| `manifests/lab-start.yaml` | The workstation pod |
| `docs/overview.md` | What the environment contains and ideas to try |
