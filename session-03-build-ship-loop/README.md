# Session 3 — The full loop, by hand (then automated with Skaffold)

Dockerfile → build → push → `kubectl --dry-run` manifests → deployed and
serving. Every step done manually so you know exactly what's happening
underneath. Then we hand the same loop to **Skaffold** and watch one command
do all of it, and re-do it on every file save.

Same philosophy as the rest of the program: manual first, so you can tell
when the tool is wrong.

## Contents

1. [Part 1: The loop by hand](#part-1-the-loop-by-hand)
2. [Part 2: What Skaffold is and why use it](#part-2-what-skaffold-is-and-why-use-it)
3. [Part 3: Hands-on lab](#part-3-hands-on-lab-skaffold-lab)
4. [Part 4: Understanding what you saw](#part-4-understanding-what-you-saw)
5. [Troubleshooting](#troubleshooting)

Prerequisites: the `kind` cluster from [session 1](../session-01-cluster-up/)
and the Gitea registry from [session 2](../session-02-registry/).

---

## Part 1: The loop by hand

For every code change, the manual inner loop looks like this:

```bash
docker build -t gitea:3000/admin/hello-skaffold:v2 app/
docker push gitea:3000/admin/hello-skaffold:v2
(cd app && python3 test_main.py)                 # run the tests
# edit the image tag in k8s/deployment.yaml
kubectl apply --dry-run=client -f k8s/           # sanity-check manifests
kubectl apply -f k8s/
kubectl rollout status deploy/hello-skaffold
kubectl logs -f deploy/hello-skaffold
```

Seven commands, one hand-edited tag, and it all repeats after every edit.
That repetition is the problem Skaffold solves.

---

## Part 2: What Skaffold is and why use it

Skaffold automates the **build → test → deploy** loop for Kubernetes apps.
You describe the pipeline once in `skaffold.yaml`, and one command runs it
the same way every time.

### What `skaffold run --tail` does for you

| Output line | What Skaffold did |
|---|---|
| `Generating tags...` | Picked an image tag. It fell back to `latest` when the git tagger had nothing to work with (the "Some taggers failed" warning). |
| `Checking cache... Found Remotely` | Skipped the build because the image already exists in the registry. |
| `Running custom test command` | Ran your tests before deploying. If they fail, nothing is deployed. |
| `Tags used in deployment ...@sha256:...` | Pinned the deployment to the exact image digest, so the deploy is reproducible. |
| `Loading images into kind` | Got the image into the local cluster without a manual push. |
| `deployment ... configured` | Applied the manifests with the new image reference. |
| `Waiting for deployments to stabilize` | Blocked until the rollout was healthy, and fails the command if it isn't. |
| `[hello-skaffold] GET /healthz` | Streamed pod logs to the terminal (`--tail`). |

### Use cases

1. **Inner-loop development: `skaffold dev`.** The big one. It watches your
   source, then rebuilds, redeploys, and tails logs on every save. It can
   also port-forward and sync files into running containers without a
   rebuild. You get a "hot reload" experience against a real cluster.
2. **Consistent local-to-CI flow.** `skaffold build`, `test`, `deploy`, and
   `run` are the same stages on a laptop or in CI. No separate scripts for
   each.
3. **Multi-environment config.** Profiles in `skaffold.yaml` (e.g.
   `-p dev`, `-p prod`) switch between local kind, NP, and prod. The
   pipeline stays the same; only the cluster and settings change.
4. **Tool-agnostic.** Docker, Jib, Buildpacks, or Bazel for builds; kubectl,
   Helm, or Kustomize for deploys. Swap tools without changing the workflow.
5. **Debugging and CI/CD building blocks.** `skaffold debug` attaches
   debuggers. `skaffold render` outputs final manifests (useful for GitOps).
   `skaffold build --file-output` produces artifact metadata to pass between
   pipeline stages.

### Pros

- One command replaces the whole build/test/deploy sequence.
- Automatic rebuild and redeploy on save (`skaffold dev`).
- File sync skips the rebuild for files that don't need one.
- Test gate: a failing test blocks the deploy.
- Image tags are pinned to digests, so deploys are reproducible.
- Same pipeline locally and in CI; profiles for each environment.
- Works with the build and deploy tools you already use.
- Built-in port-forwarding and log tailing.

### Cons / when it's not worth it

- **A single service you deploy rarely.** A `kubectl apply` or Helm command
  is simpler.
- **Teams already on GitOps (Argo CD, Flux).** Skaffold's value there is
  mostly local dev (`skaffold dev`), since the GitOps tool owns deploys.
- **Overlap with alternatives.** Tilt and DevSpace cover similar ground, so
  it's partly a preference call.
- **Another config file and tool to learn and keep in sync** with your
  Dockerfile and manifests.
- **Rebuild latency.** A full image build per change is slower than a local
  hot-reload server unless you set up file sync.

### When does Skaffold rebuild?

Only when something is **watching**. This is the most common point of
confusion:

- `skaffold run` is a **one-shot**. It builds, deploys, and (with `--tail`)
  streams logs, but it does **not** watch your source. Edits afterwards are
  ignored until you run it again.
- `skaffold dev` **watches** and reacts to changes.

What triggers what in `skaffold dev`:

| Change | Result |
|---|---|
| A file in an artifact's build context that the Dockerfile uses (`COPY`/`ADD`) or the Dockerfile itself | Rebuild, then redeploy |
| A file matched by a `sync:` rule | Copied into the running container, no rebuild |
| A file excluded by `.dockerignore` | Ignored |
| A k8s manifest | Redeploy only, no rebuild |
| `skaffold.yaml` | Skaffold reloads its configuration |

Why a change might seem to do nothing, even in `dev`:

1. The file isn't in the build context (check `context:` in `skaffold.yaml`).
2. `.dockerignore` excludes it.
3. The build cache hash didn't change, so the build was skipped
   (`Found Locally` / `Found Remotely`).
4. A `sync:` rule applied, so the file was copied but your app didn't reload.
5. The test step failed, so the deploy was blocked and the old version keeps
   running.
6. Trigger mode is manual (`--auto-build=false`).

Debug it with `skaffold dev -v debug`, which logs what is watched and why a
change did or didn't register.

---

## Part 3: Hands-on lab (`skaffold-lab/`)

[`skaffold-lab/`](skaffold-lab/) is a tiny Python HTTP app wired to a local
`kind` cluster and the Gitea registry from session 2.

```
skaffold-lab/
├── app/
│   ├── Dockerfile       # python:3.12-slim, copies main.py + message.txt
│   ├── main.py          # HTTP server; VERSION constant, reads message.txt per request
│   ├── message.txt      # the file we sync WITHOUT a rebuild
│   └── test_main.py     # the test gate: fails if VERSION is empty
├── k8s/
│   └── deployment.yaml  # Deployment + Service
└── skaffold.yaml        # build (+ sync), test, deploy, port-forward
```

### Step 1: Install Skaffold

macOS (Homebrew):

```bash
brew install skaffold
```

Linux:

```bash
curl -Lo skaffold https://storage.googleapis.com/skaffold/releases/latest/skaffold-linux-amd64
sudo install skaffold /usr/local/bin/
```

Verify:

```bash
skaffold version
```

You also need `docker`, `kubectl`, `kind`, and `python3` (the test step runs
on your host).

### Step 2: Check the cluster and registry

```bash
kind get clusters                          # expect: playground
kubectl config use-context kind-playground
kubectl get nodes                          # node(s) Ready
docker ps | grep gitea                     # Gitea from session 2 is running
docker login gitea:3000                    # same credentials as session 2
```

How the image gets from your laptop into the cluster: the host resolves
`gitea` to `127.0.0.1` and Docker treats it as insecure (127.0.0.0/8). The
kind node resolves `gitea` over the Docker network, and containerd has a
`hosts.toml` for `gitea:3000` that allows plain HTTP (set up in session 2).

### Step 3: Read `skaffold.yaml` before running it

```bash
cd skaffold-lab
cat skaffold.yaml
```

Map each block to a step of the manual loop in Part 1:

| Block | Replaces |
|---|---|
| `build.artifacts` + `local.push` | `docker build` + `docker push` |
| `build.artifacts[].sync` | Copying a file into a pod by hand (`kubectl cp`) |
| `build.insecureRegistries` | Telling Skaffold's registry client that Gitea speaks plain HTTP |
| `test` | `python3 test_main.py` |
| `manifests` + `deploy.kubectl` | Editing the tag, then `kubectl apply` |
| `portForward` | `kubectl port-forward svc/hello-skaffold 8080:80` |

### Step 4: One-shot first, `skaffold run`

```bash
skaffold run --tail
```

Match the output to the table in Part 2. In another terminal:

```bash
kubectl get pods
curl localhost:8080
```

Now edit `app/main.py` and look at the terminal. **Nothing happens.** `run`
doesn't watch. Press Ctrl+C, then clean up:

```bash
skaffold delete
```

### Step 5: The dev loop, `skaffold dev`

```bash
skaffold dev
```

It builds, tests, pushes to Gitea, deploys, port-forwards, and then waits.
Open <http://localhost:8080> (or `curl localhost:8080`).

Keep `skaffold dev` running and use a second terminal for the exercises below.

#### Exercise A: file sync (no rebuild)

Edit `app/message.txt`:

```bash
echo "Hello from file sync" > app/message.txt
sleep 2; curl localhost:8080
```

Expected: the new text appears within a second or two. The pod name is
unchanged, which shows there was no rebuild and no new pod.

#### Exercise B: rebuild and redeploy

Change `VERSION` in `app/main.py` from `"v1"` to `"v2"`.

Skaffold rebuilds, re-tests, and rolls the Deployment.

```bash
kubectl get pods -w        # watch the old pod terminate, a new one start
curl localhost:8080        # shows: app version: v2, and a new pod name
```

#### Exercise C: the test gate

Set `VERSION = ""` in `app/main.py`.

The test fails and Skaffold does **not** deploy the broken build. The old
version keeps serving:

```bash
curl localhost:8080        # still shows the last good version
```

Restore `VERSION = "v2"` and it recovers on its own.

#### Exercise D: a change that is ignored

Create a file that the Dockerfile doesn't copy:

```bash
echo "scratch" > app/notes.txt
```

Nothing is rebuilt, because the Dockerfile only does
`COPY main.py message.txt`. Remove the file afterwards.

Discussion question: what would you change so that `notes.txt` triggers a
rebuild? (Answer: add it to the Dockerfile's `COPY`.)

#### Exercise E: see why Skaffold did or didn't act

Stop `skaffold dev`, then:

```bash
skaffold dev -v debug
```

Repeat Exercise D and find the log lines about watched files.

### Step 6: Other modes

| Command | What it does |
|---|---|
| `skaffold run` | Build and deploy once, no watching |
| `skaffold render` | Print the final manifests with the built image tag |
| `skaffold build` | Build (and push) only |
| `skaffold deploy` | Deploy only |
| `skaffold debug` | Like `dev`, with debugger port-forwarding |
| `skaffold delete` | Remove what Skaffold deployed |

Try `skaffold render` and compare the `image:` line with
`k8s/deployment.yaml`. That difference is Skaffold's tag substitution.

### Step 7: Cleanup

Ctrl+C in `skaffold dev` removes the deployed resources automatically. If a
run was interrupted:

```bash
skaffold delete
kubectl get all        # only the default kubernetes service should remain
```

---

## Part 4: Understanding what you saw

- **Build cache.** Skaffold hashes the build inputs. Same hash means the build
  is skipped (`Found Locally` / `Found Remotely`).
- **Tagging.** The default tagger is git-based. With no git commits it falls
  back to `latest` and prints `Some taggers failed`. That is fine for a lab
  and not for real deployments. Use `-vdebug` to see the reason.
- **Digest pinning.** The deployed image is `tag@sha256:...`, so a pod always
  runs exactly the image Skaffold built.
- **Sync vs rebuild.** Sync is fast but only works for files you list and
  apps that re-read them. Everything else needs a rebuild.
- **`Images loaded in 42ns`.** Nothing needed loading into the kind nodes
  because the image was already available. That matches `Found Remotely`.

---

## Troubleshooting

| Symptom | Likely cause and fix |
|---|---|
| `ImagePullBackOff` with a 401 | The Gitea package is private. Make it public in Gitea or add an `imagePullSecret`. |
| `ImagePullBackOff`, `http: server gave HTTP response to HTTPS client` | containerd's `hosts.toml` for `gitea:3000` is missing on the kind node. Revisit session 2. |
| `skaffold dev` can't push | `docker login gitea:3000` has expired, or the `gitea` hostname doesn't resolve to 127.0.0.1 on the host. |
| Edited a file and nothing happened | You ran `skaffold run` (no watch). Use `skaffold dev`. Otherwise see "When does Skaffold rebuild?" above. |
| `Some taggers failed` | No git commits in the directory, so the tagger fell back to `latest`. Harmless in the lab. |
| Deploy never happens after an edit | The test step is failing. Read the test output in the `skaffold dev` terminal. |
| `connection refused` on `localhost:8080` | Port-forward only exists while `skaffold dev` or `run` is running. Check that port 8080 isn't used by another process. |
| `kubectl` talks to the wrong cluster | `kubectl config use-context kind-playground`. |

## Further reading

- Skaffold quickstart: <https://skaffold.dev/docs/quickstart/>
