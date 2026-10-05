# Installing Docker + kind (Kubernetes in Docker)

Step-by-step walkthrough to get a local Kubernetes cluster running before
session 1. If you already passed `prework/check.sh`, Docker is done —
jump to [Step 2](#step-2-install-kind).

## Step 1: Install Docker

`kind` runs Kubernetes nodes as Docker containers, so Docker has to be
installed and the daemon running first.

### macOS

Download and install [Docker Desktop](https://www.docker.com/products/docker-desktop/),
then launch it from Applications. Wait for the whale icon in the menu bar to
stop animating — that means the daemon is up.

Verify:

```bash
docker --version
docker info
```

`docker info` must succeed (not just `docker --version`) — that's the
check that confirms the daemon is actually running, not just installed.

### Linux

```bash
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker "$USER"
```

Log out and back in (group membership doesn't apply to your current shell
until you do), then verify the same way:

```bash
docker info
```

### Windows

Install [Docker Desktop](https://www.docker.com/products/docker-desktop/)
with the WSL2 backend (the installer prompts for this — accept it). Run
all commands in this guide from a WSL2 terminal (Ubuntu), not PowerShell.

## Step 2: Install kind

`kind` (Kubernetes IN Docker) is a single static binary — no package
manager required, though package managers work too.

### macOS

```bash
brew install kind
```

No Homebrew? Download the binary directly:

```bash
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.24.0/kind-darwin-arm64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind
```

(Use `kind-darwin-amd64` instead if you're on an Intel Mac — check with
`uname -m`: `arm64` = Apple Silicon, `x86_64` = Intel.)

### Linux

```bash
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.24.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind
```

### Windows (WSL2)

Same as Linux, run from your WSL2 terminal.

### Verify

```bash
kind version
```

## Step 3: Install kubectl

`kubectl` is the command-line tool you'll use to talk to the cluster.

### macOS

```bash
brew install kubectl
```

### Linux / WSL2

```bash
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/
```

### Verify

```bash
kubectl version --client
```

## Step 4: Create your first cluster

```bash
kind create cluster --name playground
```

⚠️ **The first run can take 10+ minutes — this is normal, not stuck.**
`kindest/node` is a ~1.3GB image (it bundles a full Kubernetes control
plane), so the very first pull on a fresh Docker install is the slowest
part of this entire walkthrough by far. The spinner next to
`Ensuring node image (kindest/node:v...) 🖼️` can sit there for several
minutes with no visible progress bar — **let it keep running.** Every
subsequent `kind create cluster` (even a different cluster name) reuses
the already-pulled image and comes up in under a minute.

If you want to confirm it's actually working and not frozen while you
wait, open a second terminal and watch Docker pull the image in
real time:

```bash
docker images   # size climbs from nothing to ~1.3GB as the pull progresses
```

```mermaid
flowchart LR
    A["kind create cluster<br/>(1st time ever)"] --> B{kindest/node image<br/>cached locally?}
    B -->|No| C["Pull ~1.3GB image<br/>⏱️ ~10 min (network-dependent)"]
    B -->|Yes| D["Reuse cached image<br/>⏱️ under 1 min"]
    C --> E[Cluster up]
    D --> E
    E --> F["kind delete cluster"]
    F -.->|image stays cached| B
```

The slow part only happens once per machine — deleting and recreating
the cluster afterward (which you'll do constantly in this mentorship)
stays fast because the image never goes away unless you explicitly
`docker rmi` it.

You'll see output ending in something like:

```
 ✓ Ensuring node image (kindest/node:v1.37.0) 🖼️
 ✓ Preparing nodes 📦
 ✓ Writing configuration 📜
 ✓ Starting control-plane 🕹️
 ✓ Installing CNI 🔌
 ✓ Installing StorageClass 💾
Set kubectl context to "kind-playground"
You can now use your cluster with:

kubectl cluster-info --context kind-playground
```

`kind` automatically points your `kubectl` config at the new cluster — no
manual context-switching needed.

## Step 5: Confirm it's alive

```bash
kubectl get nodes
```

Expected output: one node, `STATUS = Ready` (exact `VERSION` will vary —
`kind` tracks current Kubernetes releases):

```
NAME                       STATUS   ROLES           AGE   VERSION
playground-control-plane   Ready    control-plane   49s   v1.37.0
```

Also check that Docker sees it as a running container — this is the part
that makes `kind` different from a "real" multi-machine cluster:

```bash
docker ps --filter "name=playground"
```

You should see a single container named `playground-control-plane`. That
container **is** your Kubernetes node.

## Step 6: Clean up (when you're done experimenting)

```bash
kind delete cluster --name playground
```

This is fully disposable — destroy and recreate as often as you want
during this mentorship. Nothing here is meant to be kept running
long-term.

---

**Next:** session 1 proper — kill pods and nodes on purpose and watch what
Kubernetes self-heals (and what it doesn't).
