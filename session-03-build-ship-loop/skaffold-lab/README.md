# Skaffold lab (kind)

A tiny Python HTTP app that shows what [Skaffold](https://skaffold.dev) does in the inner dev loop:
build, test, deploy, port-forward, file sync and live rebuild on a local kind cluster.

## Prerequisites

```
brew install skaffold
kind get clusters                       # expects "playground"
kubectl config use-context kind-playground
docker login gitea:3000                 # Gitea container registry, reachable from the host and the kind node
```

The image is `gitea:3000/admin/hello-skaffold`. The host resolves `gitea` to 127.0.0.1 and Docker treats it as insecure (127.0.0.0/8). The kind node resolves `gitea` over the Docker network, and containerd has a `hosts.toml` for `gitea:3000` that allows plain HTTP. If pods hit `ImagePullBackOff` with a 401, make the package public in Gitea or add an `imagePullSecret`.

## Layout

- `app/` Python app, Dockerfile, test
- `k8s/` Deployment and Service (the image name `hello-skaffold` is replaced by Skaffold with the built tag)
- `skaffold.yaml` build (with file sync), test, deploy, port-forward

## Demo script

1. **Dev loop.** `skaffold dev` builds the image, runs the test, pushes the image to the local Gitea registry (`gitea:3000/admin/hello-skaffold`), deploys, and port-forwards. The kind node pulls the image from Gitea. Open <http://localhost:8080>.
2. **File sync (no rebuild).** Edit `app/message.txt`. Skaffold copies it into the running pod; `curl localhost:8080` shows the new text in a second or two.
3. **Rebuild and redeploy.** Change `VERSION` in `app/main.py` to `"v2"`. Skaffold rebuilds, re-tests and rolls the Deployment. `curl localhost:8080` shows `v2`.
4. **Test gate.** Set `VERSION = ""` in `app/main.py`. The test fails and Skaffold does not deploy the broken build. Restore it and it recovers.
5. **One-shot modes.**
   - `skaffold run` builds and deploys once, no watching.
   - `skaffold render` prints the final manifests with the built image tag.
   - `skaffold debug` enables debugger port-forwarding.
6. **Cleanup.** Ctrl+C in `skaffold dev` removes the deployed resources. Or `skaffold delete`.
