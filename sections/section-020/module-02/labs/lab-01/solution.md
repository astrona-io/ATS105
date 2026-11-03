# Solution: Spread And Protect Harbor's Replicas

Work the task yourself first. Running `astrona submit -c sections/section-020/module-02/labs/lab-01` after a step tells you which checks pass, without telling you what is left.

The grader checks five things: at least 2 ready replicas per component, a PodDisruptionBudget with `minAvailable: 1` that allows a disruption for each component, the hostname spread constraint with `maxSkew: 1` on `core` and `registry`, a healthy Harbor, and a working push and pull.

## Step 1: Start from the installed values

```sh
helm -n harbor get values harbor -o yaml > harbor-values.yaml
kubectl -n harbor get pdb
```

The second command finds no budgets.

## Step 2: Add the budgets and the constraints

Edit `harbor-values.yaml`. Add this to each of the four component blocks (`portal`, `core`, `jobservice`, `registry`), next to its `replicas` line:

```yaml
  podDisruptionBudget:
    enabled: true
    minAvailable: 1
```

Add this to the `core` and `registry` blocks:

```yaml
  topologySpreadConstraints:
    - maxSkew: 1
      topologyKey: kubernetes.io/hostname
      whenUnsatisfiable: ScheduleAnyway
```

Keep every other line of the file as it is.

## Step 3: Upgrade

Apply it:

```sh
helm upgrade harbor harbor/harbor --version 1.19.4 --namespace harbor \
  --values harbor-values.yaml --wait --timeout 20m
```

Then check the result:

```sh
kubectl -n harbor get pdb
kubectl -n harbor get deployment harbor-core -o jsonpath='{.spec.template.spec.topologySpreadConstraints}{"\n"}'
```

The list shows four budgets with `MIN AVAILABLE` 1 and `ALLOWED DISRUPTIONS` 1. The second command prints the constraint, which includes a label selector that the chart added.

## Step 4: Prove it before the grader does

```sh
ws() { kubectl -n workstation exec -i deploy/workstation -- "$@"; }
ws curl -s https://harbor.localtest.me:8443/api/v2.0/health | ws jq -r '.status'
ws regctl registry login harbor.localtest.me:8443 -u admin -p Harbor12345
ws rm -rf /tmp/pull
ws regctl image copy harbor.localtest.me:8443/inventory/podinfo:6.15.0 ocidir:///tmp/pull:6.15.0 && echo "pull ok"
```

The status is `healthy` and the pull prints `pull ok`. Then submit:

```sh
astrona submit -c sections/section-020/module-02/labs/lab-01
```

## Why the obvious shortcuts are wrong

| Shortcut | What happens |
| --- | --- |
| `kubectl apply` of your own PodDisruptionBudget | The chart does not manage it, and it selects pods by labels you must get right |
| `minAvailable: 2` with 2 replicas | The budget allows no disruption and every drain blocks |
| `DoNotSchedule` on a one-node cluster | The second replica stays pending |
| Spread only `core` | The grader also checks `registry` |

## Common mistakes

- Putting `podDisruptionBudget` at the top level of the values. It belongs inside each component block.
- Upgrading with a file that holds only the new blocks, which drops the external services and the certificate settings.
