# Installing Gitea as our image registry

Gitea runs as a **docker-compose side application** next to the `kind`
cluster — not inside it. This is the simpler option for a 45-minute lab: no
Helm chart, no in-cluster Postgres, nothing to debug beyond two containers.

To let pods *inside* `kind` pull images from it, Gitea's container joins the
`kind` Docker network (the same network the `playground-control-plane` node
container is on), so it's reachable from inside the node by container name —
`gitea:3000`.

## 1. Add `gitea` to your hosts file

Gitea's container registry hands out auth tokens pointing back at whatever
hostname it's configured with (`DOMAIN`/`ROOT_URL`). We use the single name
`gitea` everywhere — from your host *and* from inside the `kind` node — so
there's no mismatch between "where you pushed from" and "where the cluster
tries to pull from".

```bash
echo '127.0.0.1 gitea' | sudo tee -a /etc/hosts
```

Verify:

```bash
grep gitea /etc/hosts
```

## 2. Start Gitea + Postgres

From this directory:

```bash
docker compose up -d
```

This brings up two containers:
- `gitea` — the Gitea server, with `INSTALL_LOCK=true` so it skips the
  browser setup wizard and comes up pre-configured (DB connection, root URL,
  container registry all set via environment variables in
  `docker-compose.yaml`).
- `session-02-registry-db-1` — Postgres, Gitea's database.

Give it a few seconds, then confirm it's up:

```bash
curl -s http://gitea:3000/api/v1/version
```

```json
{"version":"1.25.1"}
```

## 3. Create an admin user

No web wizard means no "create first admin account" screen either — create
it directly in the container:

```bash
docker exec -u git gitea gitea admin user create \
  --username admin \
  --password admin12345 \
  --email admin@playground.local \
  --admin
```

```
New user 'admin' has been successfully created!
```

Log in at [http://gitea:3000](http://gitea:3000) with `admin` /
`admin12345` to see the web UI.

## 4. Push an image to the registry

Gitea's package registry speaks the standard Docker/OCI registry API —
`docker login` / `docker push` work exactly like against Docker Hub.

```bash
echo admin12345 | docker login gitea:3000 -u admin --password-stdin
```

```
Login Succeeded
```

Tag any local image and push it:

```bash
docker pull alpine:3.20
docker tag alpine:3.20 gitea:3000/admin/alpine-test:1.0
docker push gitea:3000/admin/alpine-test:1.0
```

Check it landed: open
`http://gitea:3000/admin/-/packages` in a browser, or:

```bash
curl -s -u admin:admin12345 http://gitea:3000/api/v1/packages/admin
```

## 5. Let the `kind` node trust Gitea as a registry

By default, containerd (the container runtime inside the `kind` node) only
trusts HTTPS registries. Gitea here is plain HTTP, so we need to tell
containerd to treat `gitea:3000` as an allowed insecure registry.

```bash
docker exec playground-control-plane sh -c 'mkdir -p "/etc/containerd/certs.d/gitea:3000" && cat > "/etc/containerd/certs.d/gitea:3000/hosts.toml" <<EOF
server = "http://gitea:3000"

[host."http://gitea:3000"]
  capabilities = ["pull", "resolve", "push"]
EOF'
```

Point containerd at that config directory (one-time, only needed because
this `kind` cluster wasn't created with it already) and restart it:

```bash
docker exec playground-control-plane sh -c 'cat >> /etc/containerd/config.toml <<EOF

[plugins."io.containerd.grpc.v1.cri".registry]
  config_path = "/etc/containerd/certs.d"
EOF'
docker exec playground-control-plane systemctl restart containerd
```

> This edits the running node container directly, so it won't survive a
> `kind delete cluster` / recreate. For a cluster you intend to keep,
> this `containerdConfigPatches` block belongs in the `kind create cluster
> --config` file instead — see
> [containerd registry configuration](https://kind.sigs.k8s.io/docs/user/local-registry/)
> for the equivalent patch applied at cluster-creation time.

## 6. Prove a pod can pull from Gitea

```bash
kubectl run gitea-test --image=gitea:3000/admin/alpine-test:1.0 \
  --image-pull-policy=IfNotPresent --command -- sleep 3600
kubectl get pod gitea-test
```

```
NAME         READY   STATUS    RESTARTS   AGE
gitea-test   1/1     Running   0          5s
```

If it's `Running`, the loop works: build on your host → push to Gitea →
deploy a pod that pulls the exact same image. Clean up the test pod and
image once confirmed:

```bash
kubectl delete pod gitea-test
docker exec playground-control-plane crictl rmi gitea:3000/admin/alpine-test:1.0
```

## Tearing down

```bash
docker compose down
```

Gitea's data (repos, packages, the Postgres DB) lives in `./data/`, so a
`docker compose up -d` later picks up right where you left off. Delete
`./data/` for a fully fresh install.
