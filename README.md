# Kubernetes Playground

A hands-on Kubernetes mentorship program: build a full local K8s platform from
nothing — cluster, container registry, build-and-ship loop, a real app — then
hand it off to Claude via MCP and drive it conversationally.

We do it manually first so you can tell when the robot is wrong.

**Mentor:** Thiago Zago — TELUS Digital, Brazil

## Presentation

[Kubernetes Architecture & Core Concepts](https://docs.google.com/presentation/d/1fHOXTUUV5RYbK8uNZdJ-bduy93P_sAvz/edit?usp=sharing&ouid=113815947062823404274&rtpof=true&sd=true) — A Complete Visual Guide to the Control Plane, Worker Nodes, and Deployment Trade-offs

## Schedule

6 sessions, weekly, 45 minutes each.

| # | Session | Subject |
|---|---|---|
| 1 | [session-01-cluster-up](session-01-cluster-up/) | Cluster up, broken on purpose — `kind` cluster running, then kill pods and nodes to see what self-heals |
| 2 | [session-02-registry](session-02-registry/) | Your own registry — Gitea alongside `kind` via docker-compose, first image pushed and pulled |
| 3 | [session-03-build-ship-loop](session-03-build-ship-loop/) | The full loop, by hand — Dockerfile → build → push → `kubectl --dry-run` manifests → deployed and serving |
| 4 | [session-04-make-it-survive](session-04-make-it-survive/) | Make it survive — ConfigMaps, Secrets, PVC, a broken rollout, and a rollback you perform yourself |
| 5 | [session-05-claude-k8s-mcp](session-05-claude-k8s-mcp/) | Same loop, zero `kubectl` — Claude K8s MCP builds, pushes, deploys, scales, and debugs a sabotaged pod |
| 6 | [session-06-off-the-laptop](session-06-off-the-laptop/) | Off the laptop — TELUS n8n, a workflow driving the cluster through MCP |

## Appendix / bonus material

Covered only if time allows, after the 6 core sessions.

| Topic | Subject |
|---|---|
| [bonus-network-policy](bonus-network-policy/) | NetworkPolicy — block an attacker pod, let a frontend pod through, same port |

## Requirements

- Linux command line basics
- Docker installed and running

Run the pre-work check before session 1:

```bash
./prework/check.sh
```

It exits `0` (PASS) if your machine is ready, non-zero (FAIL) with a reason
otherwise. Install-only — it doesn't modify anything on your machine.

## Goals

Build a full local Kubernetes platform from nothing — cluster, build-and-ship
loop, real app — then hand it off to Claude via MCP and drive it
conversationally. We do it manually first so you can tell when the robot is
wrong.

## License

[MIT](LICENSE) — use, fork, and adapt freely for your own mentorship or
learning.
