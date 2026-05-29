# CLAUDE.md

This file provides guidance to AI Agents when working with code in this repository.

## Project Overview

This repository contains Helm charts for Cobbler, a network installation server. Currently includes:
- **cobbler-web**: Stateless Web UI frontend for Cobbler
- **cobbler-tftp**: TFTP server component for network booting

Charts are automatically published to GitHub Pages via chart-releaser on merges to main.

## Repository Structure

```
charts/
├── cobbler-web/           # Web UI chart
│   ├── Chart.yaml         # Chart metadata and version
│   ├── values.yaml        # Default configuration values
│   └── templates/         # Kubernetes manifests
│       ├── deployment.yaml
│       ├── service.yaml
│       ├── serviceaccount.yaml
│       ├── ingress.yaml
│       ├── _helpers.tpl   # Template helpers
│       └── tests/
└── cobbler-tftp/          # TFTP server chart
    ├── Chart.yaml
    ├── values.yaml
    └── templates/
        ├── deployment.yaml
        ├── service.yaml
        ├── serviceaccount.yaml
        ├── _helpers.tpl
        └── tests/
```

## Development Commands

### Linting and Testing

```bash
# Run kube-linter (uses .kube-linter.yml config)
kube-linter lint charts/

# Run chart-testing lint
ct lint --target-branch main

# Run chart-testing install (requires kind cluster)
ct install --target-branch main

# List changed charts
ct list-changed --target-branch main
```

### Local Testing

```bash
# Template a chart to see rendered manifests
helm template charts/cobbler-web

# Install chart locally
helm install cobbler-web charts/cobbler-web

# Install with custom values
helm install cobbler-web charts/cobbler-web -f custom-values.yaml

# Upgrade chart
helm upgrade cobbler-web charts/cobbler-web
```

### Version Management

When updating charts:
1. Increment `version` in Chart.yaml for chart changes
2. Update `appVersion` in Chart.yaml when updating the container image version
3. Chart versioning follows semver

## CI/CD Pipeline

### Pull Requests
On PR, two jobs run in parallel:
1. **kubelint**: Validates Kubernetes manifests using kube-linter
   - Config: `.kube-linter.yml`
   - Outputs SARIF format to GitHub Security tab
2. **lint-test**: Runs helm chart-testing
   - Lints changed charts
   - Creates kind cluster
   - Installs charts to verify functionality

### Releases
On merge to main:
- `chart-releaser-action` automatically packages and publishes charts
- Creates GitHub releases
- Updates GitHub Pages index

## Chart Architecture

### cobbler-web
- **Purpose**: Hosts the Cobbler Web UI
- **State**: Stateless (no persistent volumes needed)
- **Service**: ClusterIP on port 80 by default
- **Probes**: HTTP-based liveness/readiness on root path
- **Key feature**: Optional ingress configuration for external access

### cobbler-tftp
- **Purpose**: TFTP server for PXE boot
- **Service**: ClusterIP on port 69 (TFTP)
- **Probes**: exec-based using `tftp localhost 69 -c status`
- **Important**: No ingress (TFTP is UDP-based, not HTTP)

## kube-linter Configuration

Several checks are excluded in `.kube-linter.yml` because they're not applicable to Helm charts:
- `unset-memory-requirements`, `minimum-three-replicas`, `required-annotation-email`, `required-label-owner`:
  User-configured via values.yaml
- `use-namespace`: Set implicitly through target deployment namespace
- `non-isolated-pod`: Network layout is user-determined
- `unset-cpu-requirements`: Intentionally not set (CPU limits avoided)

## Template Helpers

Both charts use `_helpers.tpl` for consistent naming:
- `cobbler-web.fullname` / `cobbler-tftp.fullname`: Full resource name
- `cobbler-web.name` / `cobbler-tftp.name`: Chart name
- `cobbler-web.chart` / `cobbler-tftp.chart`: Chart label
- `cobbler-web.labels` / `cobbler-tftp.labels`: Common labels
- `cobbler-web.selectorLabels` / `cobbler-tftp.selectorLabels`: Selector labels
- `cobbler-web.serviceAccountName` / `cobbler-tftp.serviceAccountName`: Service account name

When modifying templates, use these helpers for consistency rather than hardcoding names.

## Common Workflow

When adding features or fixing bugs:
1. Modify templates in `charts/<chart-name>/templates/`
2. Update values.yaml if adding new configuration options
3. Run `helm template charts/<chart-name>` to verify rendered output
4. Test with kube-linter: `kube-linter lint charts/`
5. If adding new Kubernetes resources, ensure they pass kube-linter checks or add exclusions with justification
6. Bump chart version in Chart.yaml
7. Create PR - CI will validate changes