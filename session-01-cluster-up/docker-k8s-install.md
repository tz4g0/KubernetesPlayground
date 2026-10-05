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

This takes 30–60 seconds the first time (it pulls the node image). You'll
see output ending in something like:

```
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

Expected output: one node, `STATUS = Ready`:

```
NAME                       STATUS   ROLES           AGE   VERSION
playground-control-plane   Ready    control-plane   45s   v1.31.0
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
