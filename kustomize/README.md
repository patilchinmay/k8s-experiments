# Kustomize

The `base` directory contains two resources:

- deployment.yaml
- service.yaml

We use kustomize in the `overlays/prod` directory to make the changes.

Prerequisites: Kustomize v5 or later.

To view the kustomized resources, `cd overlays/prod` and run `kustomize build`.