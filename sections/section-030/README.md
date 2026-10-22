# Section 030: Backup And Restore

A backup that has never been restored is a guess. Harbor's data lives in several places at once, and a backup that misses one of them restores a Harbor that starts, shows its projects, and then fails on the first pull or the first stored password it needs.

This section names every piece a Harbor backup must contain and then runs a full restore drill: Harbor's release, database and bucket are deleted on purpose, and you bring all of it back and prove the same image returns with the same digest.

**Topic covered:** Backup and restore

## What you will learn

- The five things a Harbor backup must contain: the database, the image storage, the TLS certificate, `secretKey` and the Helm values.
- Why Harbor's records and its images must be backed up together.
- Backing up PostgreSQL with `pg_dump` and restoring it with `pg_restore`.
- Copying a bucket with `aws s3 sync`.
- What `secretKey` encrypts, and what breaks when a restored Harbor has a different one.
- Where Velero fits, and what it does not back up for you.

## The learning path

### 1. Back Up And Restore Harbor

The playground holds Harbor on external services with the image `inventory/podinfo:6.15.0`, and an empty backup bucket `harbor-backup`.

1. What To Back Up
2. A Restore Drill, followed by the lab **Back Up Harbor And Restore It After A Disaster**
3. Summary

## Section capstone: Finish A Hurried Restore

After a real outage, Harbor was restored in a hurry. It starts, but tools reject its certificate, old images do not pull, and a registry endpoint can no longer sign in. Work the capstone after the module lab.

Start the capstone:

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS105.git -c sections/section-030/capstone/labs/lab-01
```

When you think you are done, send it for grading:

```sh
astrona submit -c sections/section-030/capstone/labs/lab-01
```

When the capstone is done, remove it:

```sh
astrona destroy ats-105-capstone-030
```
