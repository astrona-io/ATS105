# Summary

Harbor holds many credentials: an encryption key, the administrator password, the database password, the Redis password, the S3 keys and several shared secrets between its components. The chart can generate most of them, but a production installation keeps them in Kubernetes Secrets that the team owns. Each chart value that names a Secret expects an exact key name, such as `password` for the database, `secretKey` for the encryption key and `REGISTRY_STORAGE_S3_ACCESSKEY` for the object store.

The encryption key `secretKey` has 16 characters. `core` reads it from a file and uses it to encrypt the credentials that Harbor stores in its database. A restored database with a different key looks healthy and fails when a feature needs a stored credential, so the key must be backed up with the database and never regenerated.

A pod reads a Secret once, at start. Changing a Secret that the chart does not own restarts nothing. To rotate the database password, change the role in PostgreSQL, update the Secret, restart every Deployment that reads it, and prove the result with the checksum of the variable in the pod and a login with the new and the old password.

The shared secrets that the chart generates are kept across upgrades with the Helm `lookup` function. Rendering without cluster access creates new values each time. The administrator password is read once, when Harbor creates the user `admin`, so changing the chart value later has no effect.

Key facts to remember:

- Use the exact key names the chart expects in each Secret.
- Never put a password in the Helm values.
- Rotate in the order: database, Secret, restart, proof.
- Back up `harbor-secretkey` together with the database.

<!-- astrona:playground:destroy -->
