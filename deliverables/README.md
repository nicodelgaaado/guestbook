# Deliverables

This directory is generated from a local equivalent workflow that uses Docker Desktop, kind, kubectl, and a local image registry instead of IBM Cloud.

- `Dockerfile`: copied from `v1/guestbook/Dockerfile`
- `app`: copied from `v1/guestbook/public/index.v1.html`
- `up-app`: copied from `v1/guestbook/public/index.v2.html`
- `crimages`: `docker image ls --digests localhost:5001/guestbook:v1`
- `hpa`: `kubectl get hpa guestbook`
- `hpa2`: `kubectl get hpa guestbook`
- `upguestbook`: `docker push localhost:5001/guestbook:v2`
- `deployment`: `kubectl apply -f v1/guestbook/deployment.yml`
- `rev`: `kubectl rollout history deployment/guestbook --revision=2`
- `rs`: `kubectl get rs`
