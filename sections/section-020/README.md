# Section 020: High Availability

One pod per component means every restart is an outage. When `harbor-core` restarts, nobody can sign in; when `harbor-registry` restarts, every push and pull in the company fails until it is back. High availability means running each component more than once, so the loss of one pod is something no user notices.

This section scales Harbor. You will learn which state the replicas must share, why the registry needs shared storage and `jobservice` needs its logs in the database, and how to prove that pushes and pulls survive the loss of a pod. It also explains what happened to the Harbor Operator.

**Topic covered:** High availability

## What you will learn

- What a highly available Harbor needs from outside the chart: database, Redis, storage and a load balancer.
- Which components scale with `replicas` and which state they must share.
- Why two registry replicas on separate filesystems lose artifacts at random.
- How to prove high availability: delete pods and keep pushing and pulling.
- Why the Harbor Operator is not the way to run Harbor today.

## The learning path

### 1. Run Harbor With High Availability

The module starts at its landing page, which also launches the playground. The playground holds Harbor on the external services with one replica of each component and the image `inventory/podinfo:6.15.0`.

1. What High Availability Needs
2. Scaling The Components And Proving It, followed by the lab **Scale Harbor To Two Replicas Per Component**
3. Summary

## Section capstone: Make A Scaled Harbor Consistent

Someone scaled Harbor in a hurry. Pulls fail one time in two, and nobody can say why, because every pod is `Running`. Work the capstone after the module lab.

Start the capstone:

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS105.git -c sections/section-020/capstone/labs/lab-01
```

When you think you are done, send it for grading:

```sh
astrona submit -c sections/section-020/capstone/labs/lab-01
```

When the capstone is done, remove it:

```sh
astrona destroy ats-105-capstone-020
```
