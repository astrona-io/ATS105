# ATS105 — Enterprise Operations, High Availability & Helm (Harbor)

Course material for the **Enterprise Operations, High Availability & Helm**
domain of the Astrona Harbor training path
([ATP020](https://github.com/astrona-io/ATP020)), which is **15% of the
path**. Written for **Harbor 2.15.4** with the `harbor-helm` chart **1.19.4**.

> **Status: draft, not yet run.** Every page, playground and lab was written
> from the Harbor 2.15 documentation and the chart source. None has been
> started on a cluster, and no lab has passed `astrona test` yet. See
> `CLAUDE.md`.

The course opens with an Introduction in `sections/intro/` (welcome, machine
setup, how the course is made). Everything else lives under `sections/`. Each
section contains:

- **A module** — a reading chapter split into a short landing page, ordered
  deep-dive parts and a summary page, a throwaway **playground** to explore in,
  and a graded **lab** placed right after the part it tests.
- **A capstone** — one larger graded lab with several independent faults.

---

## Sections

| Section | Title | Modules | Labs | Topic |
| --- | --- | --- | --- | --- |
| [010](sections/section-010) | Harbor On External Services | 1 | 1 + capstone | External PostgreSQL, Redis and S3 |
| [020](sections/section-020) | High Availability | 1 | 1 + capstone | Replicas and shared state |
| [030](sections/section-030) | Backup And Restore | 1 | 1 + capstone | Backups and a restore drill |
| [040](sections/section-040) | Upgrades And Database Migration | 1 | 1 + capstone | Chart upgrades, database moves, garbage collection |

The order follows the data. Section 010 moves Harbor's data out of its own
pods, which every later section needs: replicas can only share state that
lives outside them, a backup is a copy of those external services, and an
upgrade or a database move changes them.

---

## Modules

| Module | Reader | Parts | Labs |
| --- | --- | --- | --- |
| 010-01 | [Run Harbor On External Services](sections/section-010/module-01/course.md) | 3 | [lab-01](sections/section-010/module-01/labs/lab-01) |
| 020-01 | [Run Harbor With High Availability](sections/section-020/module-01/course.md) | 2 | [lab-01](sections/section-020/module-01/labs/lab-01) |
| 030-01 | [Back Up And Restore Harbor](sections/section-030/module-01/course.md) | 2 | [lab-01](sections/section-030/module-01/labs/lab-01) |
| 040-01 | [Upgrade Harbor And Move Its Database](sections/section-040/module-01/course.md) | 3 | [lab-01](sections/section-040/module-01/labs/lab-01) |

---

## Capstones

| Capstone | Scenario | Faults |
| --- | --- | --- |
| [010](sections/section-010/capstone/labs/lab-01) | Repair A Harbor That Cannot Reach Its Services | a Secret with the wrong key, a wrong Redis port, a bucket that does not exist |
| [020](sections/section-020/capstone/labs/lab-01) | Make A Scaled Harbor Consistent | registry replicas on separate filesystems, one core replica, file job logs |
| [030](sections/section-030/capstone/labs/lab-01) | Finish A Hurried Restore | a new certificate, the default secretKey, an image bucket never restored |
| [040](sections/section-040/capstone/labs/lab-01) | Finish A Half-Done Database Move | a stale copy on the new server, read-only mode left on, storage never collected |

---

## The lab environment

Every playground and lab is a **kind** cluster with:

- Harbor (release `harbor`, namespace `harbor`) at `https://harbor.localtest.me:8443`,
  with its certificate in the Secret `harbor-tls`, made by the bootstrap with
  `openssl`.
- PostgreSQL 15.19, Redis 7.4.11 and an S3-compatible store (versitygw) with an
  AWS command-line client in the namespace `harbor-deps`.
- The `workstation` pod with the Harbor CLI, `regctl`, `oras`, `cosign`,
  `curl` and `jq`, trusting Harbor's CA.

The plumbing of all 12 environments (manifests, bootstrap, testing, solution
and validation scripts, `config.yaml`, `prerequisites.md`, author READMEs) is
generated from one source outside this repository; change a shared piece in
every environment.

## Running a playground

```bash
astrona run --git ssh://git@github.com/astrona-io/ATS105.git -c sections/<section>/<module>/playground
astrona destroy <name>
```

## Running a lab

```bash
astrona run --git ssh://git@github.com/astrona-io/ATS105.git -c sections/<section>/<module>/labs/lab-01
astrona submit -c sections/<section>/<module>/labs/lab-01
astrona destroy <name>
```

Each lab grades the **final state** of the cluster, Harbor, the database and
the bucket. Several graders reject the plausible-but-wrong fix (a password in
the Helm values, a restore that never removed anything, scaling the registry
without shared storage, leaving Harbor read-only). Allow about 6 GiB of memory
and up to 20 minutes for an environment to start.
