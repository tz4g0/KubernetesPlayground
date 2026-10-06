# Troubleshooting techniques

A running log of useful commands for poking at a `kind` cluster and
understanding what's actually happening underneath. We'll keep adding to
this as we find more.

## Find kubelet (and other control-plane processes) inside the node

In a single-node `kind` cluster, there's no separate "kubelet container"
— `kubelet`, `kube-apiserver`, etcd, etc. all run as regular Linux
processes **inside** the one node container
(`<cluster-name>-control-plane`), managed by `systemd`.

```bash
# 1. Confirm kubelet is a real process inside the node container
docker exec playground-control-plane ps aux | grep kubelet
```

```bash
# 2. Check it as a systemd service (status, uptime, main PID)
docker exec playground-control-plane systemctl status kubelet --no-pager
```

```bash
# 3. Tail its live logs
docker exec playground-control-plane journalctl -u kubelet -f
```

This matters for later exercises: if `kubelet` is "just" a systemd
service, you could `systemctl stop kubelet` inside the node to simulate
it going unhealthy, instead of killing the whole node container.

## Checking containers in the container runtime

`kind` nodes run their own container runtime (containerd) *inside* the
node container, separate from the Docker daemon on your host. `docker
ps` only shows the one `playground-control-plane` container — it has no
visibility into the pods running inside it. `crictl` is the CRI-level
tool to list those from within the node:

```bash
# 4. List all containers known to the node's container runtime (incl. stopped ones)
docker exec playground-control-plane crictl ps -a
```

## Install metrics-server (for `kubectl top`)

`kubectl top pod` / `kubectl top node` fail with `error: Metrics API not
available` on a fresh `kind` cluster — metrics-server isn't installed by
default.

```bash
# 1. Install metrics-server
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

```bash
# 2. Patch it to skip kubelet TLS verification — kind's kubelet certs
#    aren't signed by a CA metrics-server trusts out of the box
kubectl patch deployment metrics-server -n kube-system --type='json' \
  -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'
```

```bash
# 3. Wait for rollout, then give it ~20s to scrape before testing
kubectl rollout status deployment metrics-server -n kube-system
kubectl top node
kubectl top pod -A
```

`--kubelet-insecure-tls` is fine for a disposable local lab cluster. Don't
reach for this in a real cluster without understanding what trust you're
skipping.

## Inspect etcd's Raft state

Kubernetes' cluster state (every object, every status update) is persisted
in `etcd`, a distributed key-value store built on the **Raft consensus
algorithm**. Raft's job is to keep multiple etcd members agreeing on a
single, ordered log of writes even if some members crash or the network
partitions:

- One member is elected **leader** for a given **term**; only the leader
  accepts writes.
- The leader replicates each write to a majority (**quorum**) of members
  before considering it committed — e.g. 2 out of 3, 3 out of 5.
- If the leader goes silent, the remaining members hold a new election and
  bump the term.

In a real HA cluster you'd run 3 or 5 etcd members so a quorum can survive a
member going down. A `kind` cluster runs a single member — Raft is still
technically "in charge", but with nobody to vote against, that one member is
always leader and every write commits instantly. Zero fault tolerance: lose
that etcd, lose the cluster's state.

`etcd` itself runs as a **static pod** (`etcd-playground-control-plane`),
scheduled directly by kubelet from a manifest file rather than through the
API server — the standard `kubeadm`/`kind` pattern for control-plane
components.

```bash
# 1. Find etcd's static pod + container ID
docker exec playground-control-plane crictl ps -a --name etcd
```

```bash
# 2. Ask etcd about its own Raft state (swap in the container ID from step 1)
docker exec playground-control-plane crictl exec <container-id> etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  endpoint status --write-out=table
```

Look at `IS LEADER` (true — the only member, so it always wins), `RAFT TERM`
(bumps on every re-election — ours was already at 2 after one containerd
restart), and `RAFT APPLIED INDEX` (how many log entries have been
committed and applied so far).

## Check control-plane component health

```bash
kubectl get componentstatuses
```

```
Warning: v1 ComponentStatus is deprecated in v1.19+
NAME                 STATUS    MESSAGE   ERROR
controller-manager   Healthy   ok
scheduler             Healthy   ok
etcd-0                Healthy   ok
```

The deprecation warning is expected — this API has been deprecated since
Kubernetes 1.19 (in favor of the `/healthz` endpoints), but still works
and is still the fastest one-liner to eyeball controller-manager/
scheduler/etcd health at a glance.
