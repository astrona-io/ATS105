# Reading What A Chart Version Changes

Before you upgrade, you should know what the new chart changes. The chart is versioned separately from Harbor, and it carries every Helm value, so a difference between two chart versions is a difference in what your installation can be told. This part reads that difference with Helm.

## Chart version and application version

The release in the playground shows two versions. The chart version is the version of the packaging: the templates and the default values. The application version is the version of Harbor that the chart installs by default. List the release:

<!-- astrona:playground:renew -->

```sh
helm -n harbor list
```

The `CHART` column shows `harbor-1.19.2` and the `APP VERSION` column shows `2.15.2`. A new chart can install a new Harbor, but a chart change can also change only a template. Both numbers belong in your upgrade plan.

## Which versions exist

The chart repository `harbor` is added on your machine. Ask it for the versions of the chart:

```sh
helm repo update harbor
helm search repo harbor/harbor --versions | head -5
```

The table lists the newest chart versions with their application versions. Chart `1.19.4` installs Harbor `2.15.4`, and the playground starts at `1.19.2`.

## Compare the default values

Save the default values of both versions and compare them. Every line that differs is a setting that changed between the two chart versions:

```sh
helm show values harbor/harbor --version 1.19.2 > values-1.19.2.yaml
helm show values harbor/harbor --version 1.19.4 > values-1.19.4.yaml
diff values-1.19.2.yaml values-1.19.4.yaml
```

Most differences are image tags, which follow the application version. Look for lines that are not image tags: a new key needs a decision, and a removed key that your values still use needs a change before the upgrade.

You now know how to tell the two versions apart and how to see what a new chart changes. The next question is what to do before applying it, given that Harbor cannot go back.

## Common pitfalls

> [!WARNING]
> - **Reading only the application version.** The chart can change values without a new Harbor.
> - **Comparing `helm show values` of one version.** Compare two versions with `diff`.
> - **Skipping the repository update.** Helm then sees only the versions it already knows.
> - **Ignoring a removed key.** Values that no longer exist are silently ignored.
