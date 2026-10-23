# Writing style for this repo

All study text here (course pages, lab docs, READMEs, comments in YAML and
scripts) is for people learning a technical subject, often for a
certification exam. Many of them are not native English speakers and have no
university degree.

## Technical documentation in plain English

This is technical documentation. Say exactly what the system does, with the
real technical terms, in clear and simple English. Never hide a concept
behind a metaphor, a made-up name or a vague word: the reader must learn the
words they will meet in the product, the logs and the exam.

Strict guidelines:

1. Use the correct technical term every time (request, response, pod,
   namespace, Service, sidecar proxy, certificate, mTLS, JWT, listener). The
   first time a term appears in a file, define it in one plain sentence that
   says what it is and what it does. Spell out every acronym on first use.
2. No metaphors or analogies in explanations. Not "the communications
   officer", but "the sidecar proxy (Envoy)"; not "a signal", but "a
   request"; not "the planet", but "the namespace".
3. Simple sentences. Target a Flesch-Kincaid Grade Level of 8 or 9 for the
   prose around the terms. Keep sentences direct; split long sentences into
   two. No corporate buzzwords.
4. Use short paragraphs (max 3-4 sentences per paragraph).
5. Use the active voice ("istiod sends the configuration", not "the
   configuration is sent").

## How this applies to course material

- **Know which file you are in.** A module has a short landing page, a few
  deep-dive parts and a summary page. The landing page is a map: goals, what
  to know first, the order of the parts. The real teaching goes in the parts.
  The summary closes the module. A lab
  has a task, a step-by-step solution and a short intro. Keep each file to its
  job. Do not add "Prerequisite: ... Next: ..." navigation lines to pages;
  the landing page and the course outline already give the order.
- **Keep each part short.** One idea per part, about 5 to 8 minutes of
  reading and at most about 8 command blocks, so a learner can finish it with
  the playground in one sitting of about 15 minutes. Split at a natural seam
  where each half ends with something the learner has seen work. Never split
  only to hit a number. When you split, renumber the files, fix every "Part N"
  reference in the module and `astrona.yaml`.
- **Read like a book, not like a web page.** Each part reads as a chapter of
  a technical book. Open with a short paragraph on the problem it solves and
  why it matters. Link each paragraph to the next with a transition sentence.
  Close with a paragraph that sums up what the reader now knows and the
  question still open, before `## Common pitfalls` and the mission. Write
  explanations as prose; keep bullets for real lists (fields, ordered steps,
  options). Use `##` only when the topic changes and `###` only inside a long
  section, never for a single command. Weave hands-on steps into the text:
  one or two sentences on what to run and why, the command, the real output,
  then a sentence or two on what it shows.
- **The module ends with a summary.** The last page of every module is
  `course-0N-summary.md` with the title `# Summary`: a few short prose
  paragraphs on what the reader learned, organised by idea, optionally with
  one short list of key facts. It names no parts, modules, sections or
  chapters, and has no links, lab table, quiz or commands. Its last line is
  `<!-- astrona:playground:destroy -->` on its own line; the platform turns it
  into the step that removes the playground.
- **Every heading gets an intro.** A `##` section that has `###`
  subsections starts with one to three sentences that say what the section
  is about and why it matters, before the first `###`. Never put a `###`
  directly under a `##`.
- **Every module stands on its own.** Never refer to other sections or
  modules: no "see section 040", "as module 3 showed", "you met this in
  section 000", and no links to pages in another module. If the reader needs
  a fact from elsewhere, state the fact directly in one or two sentences.
  This also goes for parts of the same module: never write "Part 2 shows",
  "from Part 1" or "as in Part 3". Say the fact itself ("the commands below
  need the `scout` `DestinationRule` applied"). This includes the summary.
  The landing page does not have a "Where this fits" section.
- **Write words out in full.** Do not use informal short forms in prose:
  write "communications", "configuration", "repository", "administrator",
  "for example" and "that is", never "comms", "config", "repo", "admin",
  "e.g." or "i.e.". Names in code, commands and file paths stay as they are.
- **Exam terms stay.** The product's own names are what the reader must learn
  (for example a resource kind, a field, a command). Use them as they are and
  define each one in plain technical words the first time it appears in a
  file. Spell out acronyms on first use, with a short plain meaning.
- **The space theme is only for examples.** Space appears in two places and
  nowhere else: the names of the example workloads (the Starfleet: `bridge`,
  `scout`, `shuttle`, `probe`, the `starfleet` and `outpost` namespaces) and
  the short scenario that opens a lab task or a practice exercise (for
  example "the `drifter` in `outpost` must keep reaching the probe"). The
  explanation around an example is plain technical text: write "the
  `shuttle` pod sends a request to the `probe` Service", never "the shuttle
  sends a signal to the probe ship". Do not address the reader as an
  astronaut, and do not use space metaphors (communications officer, mission
  control, badge, airlock, guest list, star chart) for Istio or Kubernetes
  concepts. Titles of pages and labs name the technical task ("Require mTLS
  With PeerAuthentication"), not a space story.
- **Show one real example before the rule.** Start with a concrete case the
  reader can run, then give the general rule.
- **Say which part does the work.** Readers often mix up the parts of a system
  that sit close together. Whenever something happens, say which component
  did it.
- **Never change code to fit the style.** Commands, configuration files, field
  names, resource names, log lines and command output stay exactly as they
  are. They were run and checked on a real system. Never make up command
  output. If you shorten it, say that you did.
- **Prose only.** The grade-level and sentence rules apply to explanations.
  They do not apply to code blocks, tables of field names or reference lists
  (those may stay short and dense).
- **Keep the page furniture the same.** Hands-on steps are part of the prose
  (see "Read like a book"), not boxes or headings of their own. A `> [!TIP]` box is
  only for a real tip: advice the reader can reuse beyond this one step (a
  habit, a shortcut, how to spot a problem, an exam habit). Everything else
  is a normal sentence: notes about the current step ("if the log line is
  old, run it again"), background facts, optional extra steps, and plain
  information. Never a command snippet, never two in a row, and most pages
  need zero or one tip. Each part ends with a
  `## Common pitfalls` `> [!WARNING]` block for that part only. Use a Mermaid
  diagram for a flow, an order or a state change, keep it under about 12
  boxes, and follow it with one sentence that says what it shows.
- **Labs come right after the part they practise.** Do not collect all
  graded labs at the end of a module. In `astrona.yaml`, put each lab (its
  `question.md` reading and the `lab` entry) right after the reading part it
  tests. If a part teaches a gradeable skill and no lab covers it, create a
  new lab. That part then ends with a `## Your mission: <lab title>` section:
  one sentence on what the reader can now do, one on what the mission asks,
  then pause the playground (`astrona stop <playground name>`), the
  `astrona run` and `astrona submit` commands, and finally
  `astrona destroy <lab name>` plus `astrona start <playground name>`.
- **Renew the playground before hands-on work.** Every reading part that
  runs commands has `<!-- astrona:playground:renew -->` exactly once, on its
  own line, right before the first hands-on step (the first "Save this as"
  or the first command block), so the playground timer is reset before the
  learner needs the playground. Not on landing pages (they carry
  `<!-- astrona:playground -->`), summary pages (they carry
  `<!-- astrona:playground:destroy -->`) or pages without commands.
- **Mermaid without HTML.** The platform renders Mermaid with HTML labels
  switched off, so `<br/>` and any other HTML tag break the drawing. Rules:
  - One line per box, no `<br/>`, no HTML. Keep the box to the thing's name
    (`"scout-v2"`, `"istiod"`, `"Service: scout"`).
  - Put the logic on the arrows: `E -->|"version: v2"| P2`,
    `I -->|"CDS"| C`, `A -->|"end-user: jason"| B`. Keep edge labels short.
  - Quote every label. Prefer `flowchart TB`; use `LR` only for a short chain.
  - Sequence diagrams: short participant aliases (`participant S as shuttle`)
    and short message text.
  - Anything longer (cluster names, full hostnames) goes in the sentence under
    the diagram.
- **Every course starts with an Introduction.** It lives in `sections/intro/`
  and is the first entry in `astrona.yaml` (`id: module-intro`, title
  "Introduction"). It has exactly these four pages, in this order:
  - `README.md`, `# Introduction`: what the introduction covers and its three
    pages, named in prose (no links), ending with the topic the course starts
    with.
  - `course-01-welcome.md`, `# Welcome To The Course`: who the course is for,
    the exam domain and what the reader can do at the end, the words the
    course uses, the example app, how the course is laid out and how to read
    a page.
  - `course-02-get-your-machine-ready.md`, `# Get Your Machine Ready`: the
    tools to install, the `astrona` commands used every day, and what to do
    when a start goes wrong.
  - `course-03-how-this-course-is-made.md`, `# How This Course Is Made`: how
    content is written and checked, the maintainers, how to report a mistake,
    and the license.
  The Introduction teaches no product content and has no playground, labs or
  summary. Its only links are the repository's contributors page, issues
  page and license.
- **No links to other course files.** A course page (every reading listed in
  `astrona.yaml`, the playground guide `docs/overview.md`, and a lab's
  `question.md` and `solution.md`) never links to or points the reader at
  another page or file of the repository: no links to parts, summaries,
  labs, `question.md`, other modules, sections or the Introduction, and no
  "see `practice.md`" or "open `config.yaml`". The platform shows the pages in
  the order of `astrona.yaml`, so a link only adds a second, often wrong,
  path. Name a thing in plain words when the reader needs it ("the task is on
  the next page"), and state a fact on the page itself instead of sending the
  reader somewhere else. Repository files for authors (the root `README.md`,
  a lab's or playground's `README.md`) may link.
- **No links to outside sources.** Course pages, labs and playground docs do
  not link to or point at outside websites (the one exception is the
  `resources` field of a lab entry in `astrona.yaml`) (official docs, GitHub, blogs,
  RFCs), and they have no "Reference" or "Official docs" lists. Everything the
  reader needs is explained on the page itself. Not affected: addresses the
  reader actually uses in a command or browser (`http://127.0.0.1:9080`,
  `curl https://httpbin.org`), and the Introduction's contributors and
  "report a mistake" links.
- **Configuration goes to a file first.** Whenever the reader should apply
  YAML (course parts, playground docs, labs), use three separate steps:
  1. "Save this as `virtualservice-scout.yaml`:" followed by a plain
     ` ```yaml ` block with only the YAML. No `cat > file <<'EOF'`, no
     `kubectl apply -f - <<EOF`, no shell around it.
  2. "Apply it:" followed by a ` ```sh ` block with only
     `kubectl apply -f virtualservice-scout.yaml`.
  3. "Then check the result:" followed by the check commands, if any.
  The file name says the kind and the object. If a value must come from the
  reader's cluster (an IP address), use a placeholder like `<PARTNER>` in the
  YAML and say how to get the value (`echo $PARTNER`); never put shell
  variables inside YAML. Apply an object the first time its YAML appears; do
  not show it once "to read" and paste it again later. Never tell the reader
  to apply something from the playground's `examples/` folder: they start the
  playground with `astrona run`, so that folder is not on their machine.
- **Helpers have readable names.** Shell helper functions and variables use
  names that say what they do (`check_route`, `count_versions`,
  `$SERVICE_URL`), never single letters.


## About this repo (ATS105 only)

Everything above is general and can be copied to other course repositories. This
section is only true for this one.

### What the student is trying to learn

- **The goal:** master the **Enterprise Operations, High Availability & Helm**
  domain of the **Harbor** training path (`ATP020`). It is 15% of the path.
  There is no official Harbor certification exam; the path's domains and
  weights are Astrona's own, set in `ATP020/path.yaml`.
- **What the domain really tests:** running Harbor the way a platform team
  runs it in production: on external PostgreSQL, Redis and object storage,
  with more than one replica per component, with backups that really restore,
  and with upgrades and database moves that keep the data. Every explanation
  should lead to a command the student can run, and every fix should be proved
  with an artifact that pushes or pulls, Harbor's health endpoint, and the data
  where it belongs (tables in PostgreSQL, blobs in the bucket).
- **The sections:**

  | Section | Title | Topic |
  | --- | --- | --- |
  | 010 | Harbor On External Services | External services |
  | 020 | High Availability | High availability |
  | 030 | Backup And Restore | Backup and restore |
  | 040 | Upgrades And Database Migration | Upgrades |

- **The versions:** **Harbor v2.15.4** with the `harbor-helm` chart **1.19.4**
  (`appVersion` 2.15.4), and chart **1.19.2** (Harbor 2.15.2) as the starting
  point of the upgrade module; Helm **3.22.1**; PostgreSQL **15.19**
  (`postgres:15.19-alpine`, the same major version as Harbor 2.15's own
  `harbor-db` image); Redis **7.4.11** (`redis:7.4.11-alpine`); S3 through
  `versity/versitygw:v1.9.0` with `amazon/aws-cli:2.38.4` as the client. The
  workstation tools are the same as in ATS100. Do not teach fields, flags or
  output from other versions without saying so.
- **The main sources:** the Harbor documentation,
  <https://goharbor.io/docs/2.15.0/> (in particular the high availability,
  upgrade and garbage collection pages), and the chart's own `values.yaml`
  at tag `v1.19.4` of `goharbor/harbor-helm`, which is the only complete list
  of Helm values. Check every page against them.

### Status: built, not yet run

The first version of this repository was written from the Harbor 2.15
documentation and the chart source **without a live run**. No playground or
lab has been started, and no `astrona test` has passed yet. Until a maintainer
runs them:

- Pages describe results in words. Do not add `text` output blocks until the
  output comes from a real run, and then paste it exactly.
- Treat every lab as unverified. Run `astrona validate` and `astrona test` on
  each one, one cluster at a time, before the course goes past `maturity:
  draft`.
- Remove this subsection when every lab has passed `astrona test`.

Facts to check first on a live run: that the registry (Distribution 2.8.3,
Harbor's fork) talks to versitygw with path-style requests when only
`regionendpoint` is set; that `/api/v2.0/systeminfo/getcert` serves the CA from
`caSecretName` when `expose.tls.certSource` is `secret`; the pod labels
`component=core` and `component=registry`; the API bodies of
`POST /registries/ping`, `PUT /configurations` (`read_only`) and
`POST /system/gc/schedule`, and the `job_parameters` field of
`GET /system/gc`.

### Terms, not metaphors

| Term | First-use definition (example wording) |
| --- | --- |
| External database | A PostgreSQL server that runs outside the Harbor chart; Harbor stores projects, users, artifacts metadata and policies in it |
| External Redis | A Redis server outside the chart; Harbor keeps the job queue, sessions and caches in it, in separate database indexes per component |
| Redis Sentinel | Redis's high-availability mode: Sentinel processes watch a primary and promote a replica; Harbor connects through `sentinelMasterSet` |
| Object storage / S3 | Storage that keeps files as objects in buckets over an HTTP API; Harbor's registry stores image layers and manifests there with `persistence.imageChartStorage.type: s3` |
| ReadWriteMany (RWX) | A volume access mode where pods on many nodes can mount the same volume for writing |
| Replica | One copy of a component's pod; `<component>.replicas` sets how many |
| Job logger | Where `jobservice` writes job logs: `file`, `database` or `stdout`; with many replicas use `database` |
| `secretKey` | The 16-character key Harbor uses to encrypt stored secrets, such as registry endpoint passwords |
| Schema migration | The changes `core` makes to the database tables when a newer Harbor starts on an older database; it cannot be undone |
| Read-only mode | A Harbor setting that refuses pushes and deletions but allows pulls |
| Garbage collection (GC) | A `jobservice` job that deletes blobs no manifest references, so deleted images free their storage |
| Harbor Operator | A Kubernetes operator for Harbor; its GitHub repository `goharbor/harbor-operator` is archived and has had no release since v1.3.0 (2022) |

### The example workloads

| Name | What it is |
| --- | --- |
| Harbor (namespace `harbor`, Helm release `harbor`) | Harbor at `https://harbor.localtest.me:8443`. TLS from the Secret `harbor-tls` (a lab CA and a certificate made by the bootstrap with `openssl`), `caSecretName: harbor-tls`, Trivy and metrics off, no PersistentVolumeClaims |
| Secrets in `harbor` | `harbor-tls` (`tls.crt`, `tls.key`, `ca.crt`), `harbor-secretkey` (`secretKey` = `lab-secretkey-16`), `harbor-database` (`password`), `harbor-s3` (`REGISTRY_STORAGE_S3_ACCESSKEY`, `REGISTRY_STORAGE_S3_SECRETKEY`). Lab-only values |
| `postgres` (namespace `harbor-deps`) | PostgreSQL 15.19, user `harbor`, password `harbor-db-password`, database `registry`, an `emptyDir` at `/backup` for dumps |
| `postgres-new` | A second, empty PostgreSQL with the same settings; section 040 only |
| `redis` | Redis 7.4.11 on port `6379`, no password |
| `versitygw` (Service `s3`, port `9000`) and `s3-client` | The S3-compatible store (keys `harbor-s3` / `harbor-s3-secret`, buckets `harbor` and `harbor-backup`) and a pod with the AWS command-line tool |
| `mirror` | A Distribution 3.1.2 registry with basic authentication (`mirror` / `mirror-password`); section 030 capstone only |
| `workstation` | As in ATS100: `harbor`, `regctl`, `oras`, `cosign`, `curl`, `jq`, Harbor's CA trusted at pod start |
| Project `inventory` | Holds `inventory/podinfo:6.15.0`, copied from `ghcr.io/stefanprodan/podinfo:6.15.0` |

Pages use these helpers, defined once per page that needs them:

```sh
ws() { kubectl -n workstation exec -i deploy/workstation -- "$@"; }
harbor_api() {
  if [ -n "${3:-}" ]; then
    ws curl -sS -u admin:Harbor12345 -X "$1" -H 'Content-Type: application/json' \
      --data "$3" "https://harbor.localtest.me:8443/api/v2.0$2"
  else
    ws curl -sS -u admin:Harbor12345 -X "$1" "https://harbor.localtest.me:8443/api/v2.0$2"
  fi
}
```

The helpers work in both bash and zsh; do not use `${var:+...}` word
splitting in page helpers.

### Environment facts the text must respect

- **Harbor images are amd64 only (seen on a live run, 2026-10-23).** On an
  arm64 machine (Apple silicon) every `goharbor/*` image runs under
  emulation. The bundled Valkey (Redis) crashes there with a segmentation
  fault, so every values file replaces it with the multi-architecture
  `docker.io/valkey/valkey:8.1.10-alpine` (`redis.internal.image`). Keep
  that override in every new values file; the other components work under
  emulation. Upgrades must keep it too: use `--reuse-values` or a values
  file that contains it.
- **Harbor's certificate comes from a Secret, not from the chart.** Unlike
  ATS100, every environment here uses `expose.tls.certSource: secret`. The
  Harbor upgrade guide warns that a chart-generated certificate is replaced
  on upgrade, and a restore reinstalls the chart, so this course keeps the
  certificate in `harbor-tls` and backs that Secret up.
- **The workstation trusts the CA it saw when it started.** If Harbor comes
  back with a different certificate, every tool in the workstation fails with
  a certificate error. That is a fault some labs use on purpose.
- **One address everywhere:** the CoreDNS `rewrite stop` block for
  `harbor.localtest.me` from ATS100; never the one-line `rewrite name` form.
- **No rollback.** The Harbor upgrade guide says `helm rollback` is not
  supported because the database schema cannot be downgraded. Pages say
  "back up before you upgrade", never "roll back".
- **The data path of a backup:** the database (`pg_dump -Fc` to
  `/backup/registry.dump` in the `postgres` pod), the bucket (`aws s3 sync
  s3://harbor s3://harbor-backup`), the Secrets `harbor-tls` and
  `harbor-secretkey`, and the Helm values. Velero is described in prose only.
- **The plumbing is generated.** Manifests, bootstrap, testing, solution and
  validation scripts, `config.yaml`, `prerequisites.md` and author READMEs of
  all 12 environments come from one generator kept outside the repository.
  When you change a shared piece (the bootstrap, a helper, a values block),
  change it in every environment.
- **Harbor is big.** Allow about 6 GiB of memory per environment and up to 20
  minutes for the first start. The high-availability section runs eight
  Harbor pods.

### Where things are in this repo

The layout is the same as every Astrona course: `astrona.yaml`, `README.md`,
`sections/intro/`, `sections/section-0N0/README.md`, module pages
(`course.md`, `course-0N-*.md`), `playground/` (`config.yaml`,
`bootstrap/prepare.sh`, `manifests/harbor-deps.yaml`,
`manifests/harbor-values.yaml`, `manifests/lab-start.yaml`,
`docs/overview.md`), labs (`config.yaml`, `README.md`, `prerequisites.md`,
`question.md`, `solution.md`, `bootstrap/01-install-harbor.sh`,
`bootstrap/02-seed-state.sh`, `manifests/`, `solution/apply.sh`,
`testing/wait-for-harbor.sh`, `validation/validate-*.sh`) and one capstone
per section.

### Lab metadata in `astrona.yaml`

`training:` block: id `ATS105`, domain `Enterprise Operations, High
Availability & Helm`, weight `15`. Lab entries carry `title`, `path`,
`difficulty`, `estimated_duration`, `topic`, `task_kind`, `tags`,
`learning_goals`, `resources`, in that order, as in ATS016.

- `topic`: exactly one of `external-services`, `high-availability`,
  `backup-restore`, `upgrades`.
- `task_kind`: `build`, `troubleshooting` or `migration`.
- `tags`: 4 to 8, only from this list: `harbor-helm`, `values-yaml`,
  `external-database`, `external-redis`, `object-storage`, `s3`,
  `kubernetes-secret`, `replicas`, `job-logger`, `shared-storage`,
  `health`, `pg-dump`, `pg-restore`, `bucket-sync`, `secret-key`,
  `tls-certificate`, `restore-drill`, `chart-upgrade`, `schema-migration`,
  `read-only-mode`, `database-migration`, `garbage-collection`,
  `registry-endpoint`.
- `resources`: 1 to 4 pages on `goharbor.io` or the chart repository. The
  only place outside links are allowed.

### Running things

```bash
astrona run --git ssh://git@github.com/astrona-io/ATS105.git -c sections/section-010/module-01/playground
astrona destroy ats-105-playground-010-01
astrona run --git ssh://git@github.com/astrona-io/ATS105.git -c sections/section-010/module-01/labs/lab-01
astrona submit -c sections/section-010/module-01/labs/lab-01
astrona destroy ats-105-lab-010-01
astrona test -c sections/section-010/module-01/labs/lab-01   # authors
```

Names: `ats-105-playground-<section>-<module>`, `ats-105-lab-<section>-<module>`,
`ats-105-capstone-<section>`. Graders check **behaviour** (pushes and pulls
work, `/api/v2.0/health` is healthy, tables are in the external database,
blobs are in the bucket, the original digest comes back after a restore) and
reject the plausible but wrong fix (a database password written into the Helm
values, a restore that never dropped anything, scaling the registry without
shared storage, leaving Harbor in read-only mode). A lab's `question.md` and
`solution.md` must match what its `validation/` scripts check.

### Where to find trusted sources

- [Deploying Harbor with high availability via Helm](https://goharbor.io/docs/2.15.0/install-config/harbor-ha-helm/)
- [Upgrading Harbor deployed with Helm](https://goharbor.io/docs/2.15.0/administration/upgrade/helm-upgrade/)
- [Garbage collection](https://goharbor.io/docs/2.15.0/administration/garbage-collection/)
- [Configure global settings (read-only mode)](https://goharbor.io/docs/2.15.0/administration/general-settings/)
- [harbor-helm values.yaml at v1.19.4](https://github.com/goharbor/harbor-helm/blob/v1.19.4/values.yaml)
- The API: the Swagger file Harbor serves at `/devcenter-api-2.0`
- The archived [Harbor Operator](https://github.com/goharbor/harbor-operator)
