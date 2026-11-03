# Secrets And Helm Values In The Backup

A restore reinstalls the chart. The new installation needs the same certificate that clients trust, the same `secretKey` that encrypted the stored credentials, and the same Helm values. None of these are in the database or the bucket. This part saves them.

## What to save and why

The Secret `harbor-tls` holds `tls.crt`, `tls.key` and `ca.crt`. Without it, the restored Harbor presents a new certificate and every client fails with a certificate error. The Secret `harbor-secretkey` holds `secretKey`, the 16-character key that encrypts the credentials Harbor stores in its database. A restored database with another key looks healthy and fails when a feature needs a stored credential. The Helm values hold every setting of the installation, including the names of the external services.

Print the names and the sizes of what you must save, without printing the secret values:

<!-- astrona:playground:renew -->

```sh
kubectl -n harbor get secret harbor-tls harbor-secretkey
helm -n harbor get values harbor -o yaml | head -12
```

The Secret list shows both Secrets, each with its number of keys. The values start with the `expose` block.

## Save them outside the release

A backup of these objects must survive the loss of the namespace `harbor`. Write the values to a file and put the Secret data in a place that is not in that namespace. In the playground, the namespace `harbor-deps` plays that role. Save the values as a ConfigMap, since they hold no secrets in this course (a real installation keeps passwords in Secrets and out of the values):

```sh
helm -n harbor get values harbor -o yaml > harbor-values.yaml
kubectl -n harbor-deps create configmap harbor-values-backup --from-file=values.yaml=harbor-values.yaml
kubectl -n harbor-deps get configmap harbor-values-backup -o jsonpath='{.data.values\.yaml}' | head -3
```

The last command prints the first lines of the saved file. Reading the backup back is the check. A real backup also copies the Secrets to storage outside the cluster, with encryption, because a Secret that sits next to the data it protects protects nothing.

You now know the five parts of a Harbor backup: the database dump, the bucket copy, the certificate Secret, the `secretKey` Secret and the Helm values. Each part has a command that proves it, and a restore fails in a different way without each of them.

## Common pitfalls

> [!WARNING]
> - **Backing up the database and not `secretKey`.** Stored credentials cannot be decrypted after a restore.
> - **Letting the chart generate the certificate.** A reinstall creates a different one and clients fail.
> - **Saving the values from memory.** Use `helm get values`.
> - **Storing the Secret copy next to the data.** A single failure loses both.

## Your mission: Take A Complete Harbor Backup

You can now take each part of a Harbor backup and prove it. The graded lab asks you to take a complete backup of a running Harbor and leave Harbor untouched.

The lab runs in its own cluster, so first pause your playground. Nothing in it is lost:

```sh
astrona stop ats-105-playground-030-02
```

Then start the lab:

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS105.git -c sections/section-030/module-02/labs/lab-01
```

The task is on the next page. Solve it on your own first. When you think you are done, send it for grading:

```sh
astrona submit -c sections/section-030/module-02/labs/lab-01
```

When the lab is done, remove it and start your playground again:

```sh
astrona destroy ats-105-lab-030-02
astrona start ats-105-playground-030-02
```
