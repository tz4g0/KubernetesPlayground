# Session 2 — Your own registry

Stand up Gitea as a container image registry running alongside the `kind`
cluster (docker-compose, not in-cluster — keeps the lab simple). Push an
image to it from your host, then deploy a pod in `kind` that pulls that same
image back out.

See [gitea_install.md](gitea_install.md) for the full step-by-step.

Content for the rest of this session goes here as it's taught.
