# Summary

A Helm chart and the application it installs have separate versions. The chart version covers the templates and default values, and the application version is the Harbor release. Comparing the default values of two chart versions with `diff` shows which settings changed, and a removed key that the installed values still use needs a change before the upgrade.

Harbor does not support `helm rollback`. A new version migrates the database schema when `core` starts, and the schema cannot be downgraded. The way back is a restore, so the plan holds a custom-format dump of the database taken before the upgrade, the bucket, the certificate and `secretKey` Secrets and the installed Helm values. A dump taken after the upgrade holds the new schema and is not a way back. On a busy Harbor, read-only mode keeps pushes out of the window.

The upgrade starts from the installed values, because a values file replaces the values passed before. Harbor records the schema version in the table `schema_migrations`, with a `dirty` flag that shows a stopped migration. Three proofs close an upgrade: the chart and application version of the release, the migration table, and a complete pull.

Key facts to remember:

- Back up before the upgrade, with `pg_dump -Fc`.
- Start from `helm get values`.
- Check `schema_migrations` and `dirty` after the upgrade.
- A successful `--wait` is not proof by itself.

<!-- astrona:playground:destroy -->
