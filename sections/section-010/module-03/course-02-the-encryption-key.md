# The Encryption Key

Harbor stores some values in its database that it must be able to read again, such as the password of a replication endpoint or the credentials of a robot connection. It cannot hash them, so it encrypts them with a key. This key is `secretKey`. If a new Harbor starts on a restored database with a different key, it cannot decrypt those values. This part explains where the key comes from, how to check it, and why it is part of every backup.

## What `secretKey` is

`secretKey` is a string of exactly 16 characters. The chart's default value is `not-a-secure-key`, which is also 16 characters and also public. The `core` component reads the key from the file `/etc/core/key`. It uses it to encrypt and decrypt stored secrets with AES.

You can give the key in two ways. The value `secretKey` writes it into a Secret that the chart owns. The value `existingSecretSecretKey` names a Secret you own, with the key `secretKey`. This course always uses the second way. When you set `existingSecretSecretKey`, the chart does not create the key and ignores `secretKey`.

<!-- astrona:playground:renew -->

```sh
kubectl -n harbor get secret harbor-secretkey -o jsonpath='{.data.secretKey}' | base64 -d | wc -c
kubectl -n harbor get deployment harbor-core -o jsonpath='{.spec.template.spec.volumes[?(@.name=="secret-key")]}' | jq
```

The first command prints `16`. Count the characters, not the content. The second shows that the volume `secret-key` comes from the Secret `harbor-secretkey`.

## What goes wrong when the key changes

The database holds values that were encrypted with the old key. After a restart with a different key, `core` cannot decrypt them. The features that use a stored secret fail, for example a replication rule that needs the password of its registry endpoint. The failure appears when the feature runs, not when Harbor starts, so Harbor can look healthy while it is broken.

The same applies to a restore. A restored database plus a newly generated key is a Harbor that reports `healthy` and fails on its stored credentials. For that reason, a backup of the database is incomplete without the Secret that holds the key.

## Check the key that the pod uses

The only reliable check is to compare what the pod reads with what the Secret holds. Compare their lengths and a checksum, so that no key is printed:

```sh
kubectl -n harbor exec deploy/harbor-core -- sh -c 'wc -c < /etc/core/key; cksum < /etc/core/key'
kubectl -n harbor get secret harbor-secretkey -o jsonpath='{.data.secretKey}' | base64 -d | cksum
```

Both checksums are equal. The pod reads the key at start, so after you change the Secret, this comparison shows a difference until `core` restarts. Do not change `harbor-secretkey` on a Harbor that holds data.

You now know what `secretKey` protects, where `core` reads it, and why a backup must include it. The next question is how to change a credential that can change, such as the database password, without an outage.

## Common pitfalls

> [!WARNING]
> - **Using the default `not-a-secure-key`.** Everyone knows it.
> - **A key that is not 16 characters.** `core` refuses to start with a key of the wrong length.
> - **Backing up the database and not the Secret `harbor-secretkey`.** The restored Harbor cannot decrypt stored credentials.
> - **Generating a new key when you reinstall.** The old encrypted values stay unreadable.
> - **Treating the key like a password that you can rotate.** It cannot be rotated in place.
