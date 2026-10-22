# Welcome To The Course

This course trains you for the **Enterprise Operations, High Availability & Helm** part of the Astrona **Harbor** training path. That part is 15% of the path. This page tells you who the course is for, what you can do at the end, which words and example setup it uses, and how its pages fit together.

## Who this course is for

You run, or will run, a container registry for other teams. You know Kubernetes well enough to read Deployments, Services, Secrets and pod logs, and you have installed a chart with Helm. You know what an image tag and a digest are. You do not need to know Harbor's internals yet. Each new idea is explained the first time it appears.

## What you can do at the end

A registry that loses its data, or stops during an upgrade, stops every deployment of every team. So this course does not ask you to remember words. It asks you to move Harbor's data to services built for it, scale it, back it up, restore it, and upgrade it, and to prove each step with a real push or pull. The course has four topics.

The first topic is **Harbor on external services**. You will learn to:

- Say which Harbor component keeps which data, and where.
- Point the `harbor-helm` chart at an external PostgreSQL, an external Redis and S3-compatible object storage.
- Keep every credential in a Kubernetes Secret instead of the Helm values.

With the data outside Harbor's pods, the second topic is **high availability**. You will learn to:

- Run two or more replicas of every stateless component.
- Explain why registry replicas need shared storage and job logs need the database.
- Prove that pushes and pulls survive the loss of a pod.

The third topic is **backup and restore**. You will learn to:

- Back up the database, the image storage, the certificate, the encryption key and the Helm values.
- Restore Harbor after a disaster and prove that the same artifact comes back.

The fourth topic is **upgrades and database migration**. You will learn to:

- Upgrade Harbor with the chart, and explain why there is no rollback.
- Move Harbor's database to a new PostgreSQL server inside a read-only window.
- Free storage with garbage collection after deletions.

Everything is written for **Harbor 2.15.4** with the `harbor-helm` chart **1.19.4**.

## The words this course uses

The pages use Harbor's, Helm's, PostgreSQL's and Kubernetes' own terms, because those are the words you meet in the product, the logs and the documentation. Each term gets a short, plain definition the first time it appears on a page. A few terms come back on almost every page, so here they are up front.

A **registry** is a server that stores container images and other artifacts. Harbor is a registry with projects, access control and policies on top. An **artifact** is anything stored in the registry, and its **digest** is the hash that identifies it exactly. A **Helm value** is one setting you pass to the chart, and the chart turns the values into Kubernetes objects.

Harbor is made of several components, and you will meet all of them:

| Component | What it does |
| --- | --- |
| `core` | The API server: users, projects, policies and the token service |
| `registry` | Stores and serves image layers and manifests |
| `portal` | The web user interface |
| `jobservice` | Runs background jobs such as garbage collection |
| PostgreSQL | Holds Harbor's data: projects, users, artifact records |
| Redis | Holds the job queue and caches |

## The example setup in your playground

Every playground and lab runs the same setup. Harbor runs in the namespace `harbor` and answers at `https://harbor.localtest.me:8443`. Its external services run in the namespace `harbor-deps`: a PostgreSQL server, a Redis server and an S3-compatible object store with a client pod that has the AWS command-line tool. A `workstation` pod holds the client tools (`harbor`, `regctl`, `curl` and `jq`) and trusts Harbor's certificate, so every Harbor command runs there.

The project `inventory` holds one image, `inventory/podinfo:6.15.0`, a small web application. Many labs start with something broken or half done on purpose. That is the material, not a fault in the course.

## How the course is laid out

The course has four sections. It starts by moving Harbor's data out of its own pods, because every later topic depends on that.

| Section | What it covers |
| --- | --- |
| 010 | Harbor On External Services |
| 020 | High Availability |
| 030 | Backup And Restore |
| 040 | Upgrades And Database Migration |

Each section has one or more **modules**, and each module teaches one skill. A module brings together four kinds of material:

| What | What it is for | Graded? |
| --- | --- | --- |
| **Reading** | A short landing page, a few chapters that teach one idea each, and a summary | No |
| **Playground** | A small cluster on your own machine, to try everything you read | No |
| **Lab** | A cluster in a starting state, a task, and a grader that checks your work | Yes |
| **Capstone** | The last lab in a section, with several faults at once | Yes |

The best order is simple: read the chapters with the playground open next to them, take each lab when a chapter sends you to it, and finish each section with its capstone. The next part of this page explains how a module's pages guide you through that order.

## How to read a page

A module starts with a **landing page**. It says what the module teaches, what you should know first, and the order of its chapters. At the bottom of the landing page you start the module's playground, and you keep it running while you read.

The chapters (the parts of a module) read like the chapters of a technical book. Each one opens with the problem it solves, explains one idea in connected paragraphs, and closes with what you now know. The hands-on steps sit right in the text: a sentence or two on what to run and why, the command, and then what the result shows. Run each step in your playground as you reach it. You learn more from one real result than from a page of text.

Every chapter ends with a box of common pitfalls, the mistakes people make most often with what the chapter taught, and how to spot them. Now and then a page also has a tip box with a habit or shortcut you can use again, well beyond that page. The two boxes look like this:

> [!TIP]
> **A tip.** A habit or shortcut you can use again, well beyond this one page.

> [!WARNING]
> **Common pitfalls.** The mistakes people make most often with what you just learned, and how to spot them. Every chapter ends with one.

When a graded lab tests what a chapter taught, that chapter ends with a **Your mission** section. It tells you what the lab asks, then gives every command you need, in order: pause the playground with `astrona stop`, start the lab with `astrona run`, and send your work for grading with `astrona submit`. Solve the lab on your own before you look at its solution. When the lab is done, remove it with `astrona destroy` and start the playground again with `astrona start`, so you can carry on reading where you left off.

The last page of every module is the **Summary**. It sums up what you learned in a few short paragraphs, organised by idea. It also ends the module's hands-on work: the Summary page removes the playground, so your machine is clean before the next module.

One rule holds on every page. Code blocks are exactly what you type. Never change a command to make it "look right". If the result is different from what the page describes, that difference is the lesson.
