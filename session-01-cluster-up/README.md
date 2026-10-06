# Session 1 — Cluster up, broken on purpose

Get a `kind` (Kubernetes in Docker) cluster running locally, then
deliberately kill pods and nodes to see what Kubernetes self-heals — and
what it doesn't.

**Before this session:** [docker-k8s-install.md](docker-k8s-install.md) —
step-by-step Docker + kind + kubectl install, from a completely clean
machine.

**Troubleshooting commands:** [tshoot.md](tshoot.md) — a running log of
useful commands for poking at the cluster (find kubelet inside the node,
check component health, etc.). Keeps growing as we find more.

## Session flow

```mermaid
flowchart TD
    A[Clean machine<br/>no Docker, no kind, no kubectl] --> B[Install Docker]
    B --> C[Install kind]
    C --> D[Install kubectl]
    D --> E["kind create cluster"]
    E --> F[kubectl get nodes<br/>confirm Ready]
    F --> G[Kill a pod on purpose]
    G --> H{Did it come back?}
    H -->|Yes| I[Why: a Deployment/ReplicaSet<br/>owns it and reconciles]
    H -->|No| J[Why: a bare Pod has<br/>no controller to recreate it]
    I --> K[Kill the node container itself]
    J --> K
    K --> L{Cluster survives?}
    L -->|Single-node kind cluster| M[No — the whole control plane<br/>was that one container]
    M --> N[Discussion: why real clusters<br/>need multiple nodes]
```

The point of this session isn't memorizing commands — it's building the
instinct for **what Kubernetes self-heals automatically vs. what requires
a human (or Claude) to notice and fix.**

Content for the live kill-pods-and-nodes exercise goes here as it's taught.
