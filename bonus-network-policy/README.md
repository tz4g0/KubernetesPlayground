# Bonus — NetworkPolicy: block the attacker, let the frontend through

Covered only if time allows at the end of the course. Builds on
[session-01](../session-01-cluster-up/)'s CNI comparison table — this is
where we actually *use* the NetworkPolicy enforcement kindnet gives us for
free.

## The idea

Three pods, one `Service`-free direct-IP setup to keep it simple:

- `backend` — an nginx pod, labeled `role: backend`, listening on port 80.
- `frontend` — labeled `role: frontend`. Should be allowed to reach `backend`.
- `attacker` — labeled `role: attacker`. Should be blocked.

By default, Kubernetes pod networking is **flat and open** — any pod can
reach any other pod. A `NetworkPolicy` that selects `backend` for ingress
flips that: once *any* policy selects a pod, everything not explicitly
allowed is denied.

## 1. Create the three pods

```bash
kubectl run backend --image=nginx:alpine --labels=role=backend --port=80
kubectl run frontend --image=busybox --labels=role=frontend --command -- sleep 3600
kubectl run attacker --image=busybox --labels=role=attacker --command -- sleep 3600
kubectl wait --for=condition=Ready pod/backend pod/frontend pod/attacker --timeout=60s
```

## 2. Prove it's wide open right now

```bash
BACKEND_IP=$(kubectl get pod backend -o jsonpath='{.status.podIP}')

kubectl exec frontend -- wget -q -T 5 -O- "http://$BACKEND_IP:80" | head -1
kubectl exec attacker -- wget -q -T 5 -O- "http://$BACKEND_IP:80" | head -1
```

Both return the nginx welcome page's `<!DOCTYPE html>` line. No policy
exists yet, so there's nothing to enforce.

## 3. Apply a policy: only `role: frontend` may reach `backend` on port 80

```yaml
# allow-frontend-only.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-only
  namespace: default
spec:
  podSelector:
    matchLabels:
      role: backend
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          role: frontend
    ports:
    - protocol: TCP
      port: 80
```

```bash
kubectl apply -f allow-frontend-only.yaml
```

## 4. Retest

```bash
BACKEND_IP=$(kubectl get pod backend -o jsonpath='{.status.podIP}')

echo "-- frontend (expect: nginx HTML) --"
kubectl exec frontend -- wget -q -T 5 -O- "http://$BACKEND_IP:80" | head -1

echo "-- attacker (expect: timeout) --"
kubectl exec attacker -- wget -q -T 5 -O- "http://$BACKEND_IP:80"
```

`frontend` still gets the page. `attacker` times out — same pod, same
target, same port, the only difference is the `role` label. That's
`NetworkPolicy` enforcement, live, via kindnet's iptables controller.

## 5. Clean up

```bash
kubectl delete pod backend frontend attacker
kubectl delete networkpolicy allow-frontend-only
```

## Where to go from here

The [official NetworkPolicy docs](https://kubernetes.io/docs/concepts/services-networking/network-policies/)
example is the same idea with more knobs at once: `ipBlock` with `except`
ranges, `namespaceSelector`, multiple `from` sources combined, and a
separate `egress` rule. Once this simple version clicks, that fuller
example reads as "more of the same ingredients," not new concepts.
