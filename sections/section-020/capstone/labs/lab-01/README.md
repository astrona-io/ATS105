---
estimated_duration: 45m
---

# Make A Scaled Harbor Consistent

- **ID:** CAPSTONE
- **Slug:** ats-105-capstone-020
- **Author:** Paris Nakita Kejser
- **Type:** Astrona graded lab

Read `question.md` for the task; `solution.md` is the walkthrough. The
plumbing (manifests, bootstrap, testing, solution and validation scripts,
`config.yaml`) is generated; change shared pieces in every environment.

## Run it

```sh
astrona run -c .
astrona submit
astrona destroy ats-105-capstone-020
astrona test -c .   # authors: proves solution/apply.sh passes the graders
```

## Layout

| Path | Purpose |
| --- | --- |
| `config.yaml` | Environment definition, bootstrap and grading |
| `question.md` | The task |
| `solution.md` | Step-by-step walkthrough |
| `prerequisites.md` | Assumed knowledge and what the environment provides |
| `bootstrap/` | Helm, external services, Harbor, workstation, starting state |
| `manifests/` | `harbor-deps.yaml`, `harbor-values.yaml`, `lab-start.yaml` |
| `solution/` | Reference solution used by `astrona test` |
| `testing/` | Waits for Harbor before the reference solution |
| `validation/` | Grading scripts, one per check |
