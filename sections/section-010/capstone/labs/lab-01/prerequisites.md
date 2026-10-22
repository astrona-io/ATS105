# Prerequisites

Before starting this lab you should be able to:

- Use `kubectl` to read pods, Deployments, Secrets and logs.
- Read and write Helm values, and run `helm upgrade` with a values file.
- Use `curl` and `jq` to call a REST API and read its JSON answer.

## What the environment gives you

The lab environment builds itself before the task begins:

- A single-node `kind` Kubernetes cluster, with `kubectl` and Helm 3.22.1 on your machine.
- **Harbor** installed with the `harbor-helm` chart 1.19.4 as the Helm release `harbor` in the namespace `harbor`, at `https://harbor.localtest.me:8443`.
- PostgreSQL, Redis and an S3-compatible store (with a client pod that has the AWS command-line tool) in the namespace `harbor-deps`.
- The `workstation` pod in the namespace `workstation`, with `harbor`, `regctl`, `oras`, `cosign`, `curl` and `jq`, and Harbor's certificate authority trusted.
- The administrator account `admin` with the password `Harbor12345` (lab-only credentials).

## Working rules

- Everything is graded on the **final state** of the cluster and of Harbor.
- Change one thing at a time and check Harbor's health after each change.
- The Helm chart repository and the images need outbound internet.
