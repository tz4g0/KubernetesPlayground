# Bonus — Installing the Kubernetes Dashboard

Covered only if time allows. The
[official docs](https://kubernetes.io/docs/tasks/access-application-cluster/web-ui-dashboard/)
point at a Helm chart repo — as of this writing that repo's GitHub Pages
index is down, so this doc also covers the workaround.

## 1. Try the documented install first

```bash
helm repo add kubernetes-dashboard https://kubernetes.github.io/dashboard/
helm repo update
```

If you hit this:

```
Error: looks like "https://kubernetes.github.io/dashboard/" is not a valid
chart repository or cannot be reached: ... write: socket is not connected
```

Don't chase it as a network/VPN/IPv6 problem first — check if the repo
itself is actually serving anything:

```bash
curl -s -o /dev/null -w "%{http_code}\n" https://kubernetes.github.io/dashboard/index.yaml
```

A `404` here means the chart repo's GitHub Pages site is down upstream,
independent of your machine. That was the case when we ran this.

## 2. Workaround: install straight from the GitHub release asset

The `kubernetes/dashboard` repo redirects to `kubernetes-retired/dashboard`
these days, and its releases publish the Helm chart as a `.tgz` you can
point `helm` at directly — no working repo index required.

```bash
# find the latest release + asset URL
curl -sL https://api.github.com/repos/kubernetes/dashboard/releases/latest \
  | grep -i "tag_name\|browser_download_url"
```

```bash
# download the chart package (adjust version to whatever the above returned)
curl -sL -o /tmp/kubernetes-dashboard.tgz \
  https://github.com/kubernetes-retired/dashboard/releases/download/kubernetes-dashboard-7.14.0/kubernetes-dashboard-7.14.0.tgz
```

```bash
# install from the local chart archive instead of a repo
helm upgrade --install kubernetes-dashboard /tmp/kubernetes-dashboard.tgz \
  --create-namespace --namespace kubernetes-dashboard
```

## 3. Wait for it to come up

Dashboard v3 is a handful of separate pods behind a **Kong** API gateway
(not a Kubernetes Ingress — just Kong's standalone proxy used as an
internal reverse proxy/TLS terminator for this one release). `kong:3.9` is
a sizeable image, so first pull takes a minute or two.

```bash
kubectl -n kubernetes-dashboard get pods -w
```

Expect something like:

```
NAME                                                    READY   STATUS    RESTARTS   AGE
kubernetes-dashboard-api-5c9fc85667-ddxcr               1/1     Running   0          3m
kubernetes-dashboard-auth-6695b76f46-p62df              1/1     Running   0          3m
kubernetes-dashboard-kong-7df9869f84-vt2jp              1/1     Running   0          3m
kubernetes-dashboard-metrics-scraper-7b9fcc9c48-x6xl9   1/1     Running   0          3m
kubernetes-dashboard-web-7655865594-m4zbv               1/1     Running   0          3m
```

If `kong` sits in `Init:0/1` for a while, that's normal — check it's just
pulling its image, not actually stuck:

```bash
kubectl -n kubernetes-dashboard describe pod -l app.kubernetes.io/component=kong | grep -A2 Events
```

## 4. Access it

```bash
kubectl -n kubernetes-dashboard port-forward svc/kubernetes-dashboard-kong-proxy 8443:443
```

Dashboard is then at `https://localhost:8443` (self-signed cert — your
browser will warn, that's expected for a local lab).

## Note on Kong here

Kong ships as two different things: a standalone **Gateway** (a reverse
proxy you configure directly, e.g. via a static `ConfigMap` like Dashboard
does) and a separate **Ingress Controller** (which registers a Kubernetes
`IngressClass` and watches `Ingress` objects cluster-wide). This install
only brings the standalone Gateway — confirm with:

```bash
kubectl get ingressclass
kubectl -n kubernetes-dashboard get ingress
```

Both come back empty. Nothing here touches Kubernetes' `Ingress` machinery;
Kong is purely Dashboard's own internal front door.

## Clean up

```bash
helm uninstall kubernetes-dashboard -n kubernetes-dashboard
kubectl delete namespace kubernetes-dashboard
```
