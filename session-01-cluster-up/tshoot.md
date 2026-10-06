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
