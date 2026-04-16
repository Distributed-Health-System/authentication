# Keycloak Minikube Migration Plan

## Goal

Migrate the IAM service to Minikube using a custom Keycloak image so the realm export is bundled into the container image instead of being mounted from the infrastructure repository.

## Documentation basis

- Keycloak container docs: `start-dev --import-realm` imports JSON files from `/opt/keycloak/data/import` during startup.
- Keycloak container docs also state that initial bootstrap admin credentials should be provided through `KC_BOOTSTRAP_ADMIN_USERNAME` and `KC_BOOTSTRAP_ADMIN_PASSWORD`.
- Kubernetes ConfigMap docs: ConfigMaps are for non-sensitive configuration and fit the fixed `KC_DB=dev-mem` runtime setting.
- Minikube docs: local images can be built directly into the cluster runtime with `minikube image build` or loaded with `minikube image load`, which fits the custom-image workflow.

## Decision

Use a ConfigMap for the non-sensitive Keycloak runtime setting.

Reason:

- The realm file is embedded in the image at build time.
- `KC_DB` is non-sensitive and belongs in the ConfigMap.
- The bootstrap admin values are sensitive and must remain Secret-backed.
- The deployment should avoid any `volumes` or `volumeMounts` for realm import because the image already contains the file.

If additional non-sensitive Keycloak runtime settings are added later, they can live in the same ConfigMap.

## Implementation steps

1. Create `authentication/Dockerfile` using `quay.io/keycloak/keycloak:26.2.4` as the base image.
2. Copy `keycloak/realm-export.json` into `/opt/keycloak/data/import/realm.json`.
3. Create `infrastructure/k8s/authentication/deployment.yaml` that uses the custom image and runs `start-dev --import-realm`.
4. Create `infrastructure/k8s/authentication/configmap.yaml` for `KC_DB=dev-mem`.
5. Consume the ConfigMap from the deployment.
6. Source `KC_BOOTSTRAP_ADMIN_USERNAME` and `KC_BOOTSTRAP_ADMIN_PASSWORD` from the existing `keycloak-secrets` Secret.
7. Create `infrastructure/k8s/authentication/service.yaml` as a ClusterIP service on port 8080.
8. Create `infrastructure/k8s/authentication/kustomization.yaml` with the configmap, deployment, and service resources.
9. Do not create `secret.yaml` or `configMapGenerator` in this slice.
10. Update the root `infrastructure/k8s/kustomization.yaml` only if the authentication base must be included in the platform overlay.

## Minikube build and load notes

Use one of these approaches when testing locally:

- `minikube image build -t your-dockerhub-user/health-auth:latest -f authentication/Dockerfile authentication/`
- or build the image with Docker and then use `minikube image load your-dockerhub-user/health-auth:latest`

The deployment should reference the same image tag that is present in Minikube.

## Validation checklist

- Custom Keycloak image builds successfully.
- Realm import file is present at `/opt/keycloak/data/import/realm.json` inside the image.
- Deployment uses `start-dev --import-realm`.
- Deployment has no realm volume mounts.
- Deployment reads `KC_DB=dev-mem` from the ConfigMap.
- Bootstrap admin credentials come from `keycloak-secrets`.
- Service exposes port 8080 as ClusterIP.
- Kustomization references the ConfigMap, deployment, and service.
- No Secret manifest is introduced in the authentication repo for this assignment.
