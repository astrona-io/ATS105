# Summary

A Harbor backup has five parts: the database dump, the bucket copy, the certificate Secret, the `secretKey` Secret and the Helm values. Each part answers a different failure after a restore, and none of them is visible from the others.

The database dump should use the custom format, `pg_dump -Fc`, because only that archive can be inspected. `pg_restore --list` shows the tables with data, and `pg_restore -t` prints the rows of one table, so the dump can be proved without a restore. A dump is a snapshot, and anything pushed afterwards is not in it.

The bucket copy is made with `aws s3 sync`, which copies missing objects and deletes nothing unless `--delete` is given. The proof is a comparison of object counts. Because the database and the bucket are copied at different moments, copy the bucket after the dump, and use read-only mode when the window allows it.

The certificate decides whether clients trust the restored Harbor. The `secretKey` decides whether stored credentials can be decrypted. The Helm values name the external services and every other setting. Save all three outside the release, and read the copies back to prove them.

Key facts to remember:

- Use `pg_dump -Fc` and read the archive with `pg_restore --list`.
- Compare the object counts of the bucket and its copy.
- Back up `harbor-tls`, `harbor-secretkey` and the output of `helm get values`.
- A backup that was never read back is not a proven backup.

<!-- astrona:playground:destroy -->
