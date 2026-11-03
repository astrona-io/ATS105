# Harbor Secrets, Keys And Credentials

Harbor holds more secrets than the database password. It keeps an encryption key, an administrator password, several shared secrets between its own components, and the keys for Redis and the object store. If you do not know which Secret holds which value, you cannot rotate a password without an outage, and you cannot restore a backup that the new installation can read.

Keep one sentence in mind: **a Secret that the chart does not own is not part of a release, so a restart is the only way a pod learns that it changed.** This module explains which credentials exist, which chart values name them, how the encryption key works, how to rotate the database password, and what an upgrade does to the secrets the chart generates.

The module has four parts. **Which Credentials Harbor Holds** lists each credential, the chart value for it and the key name its Secret must use. **The Encryption Key** covers `secretKey` and what breaks when it changes. **Rotating A Credential** changes the database password with no data loss; a graded lab follows it. **Generated Secrets And The Admin Password** explains what the chart creates when you set nothing, and why changing `harborAdminPassword` later has no effect.

## Learning objectives

After this module you can:

- Name the credentials in a Harbor installation and the chart value that points each one at an existing Secret.
- Give the key name a Secret must use for the database, Redis, S3, the encryption key and the administrator password.
- Explain what `secretKey` encrypts and what happens when it is lost or changed.
- Rotate the database password and prove that Harbor uses the new one.
- Explain why a changed Secret needs a pod restart, and why the chart does not do it for you.

## Before you start

You need Kubernetes basics (Secrets, Deployments, environment variables from a Secret) and some PostgreSQL basics (a role, a password, `ALTER ROLE`).

Your playground is a single-node `kind` cluster. **Harbor 2.15.4** runs there as the Helm release `harbor` in the namespace `harbor`, installed with chart 1.19.4 on the external PostgreSQL, Redis and S3 bucket in the namespace `harbor-deps`. It answers at `https://harbor.localtest.me:8443`. The Secrets `harbor-secretkey`, `harbor-external-db` and `harbor-s3` hold the credentials. The `workstation` pod in the namespace `workstation` holds `regctl`, `curl` and `jq` and trusts Harbor's certificate authority. The administrator is `admin` with the password `Harbor12345`; these are lab-only credentials.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->
