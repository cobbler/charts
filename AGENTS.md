# CLAUDE.md

This file provides guidance to AI Agents when working with code in this repository.

## Project Overview

This repository contains Helm charts for Cobbler, a network installation server. Currently includes:
- **cobblerd**: The Cobbler backend (XML-RPC daemon + HTTP/XML-RPC API)
- **cobbler-web**: Stateless Web UI frontend for Cobbler
- **cobbler-tftp**: TFTP server component for network booting

Charts are automatically published to GitHub Pages via chart-releaser on merges to main.

## Repository Structure

```
charts/
├── cobblerd/              # Cobbler backend chart (cobblerd + http-api)
│   ├── Chart.yaml
│   ├── values.yaml
│   └── templates/
│       ├── deployment.yaml
│       ├── service.yaml
│       ├── serviceaccount.yaml
│       ├── configmap.yaml
│       ├── pvc.yaml
│       ├── ingress.yaml
│       ├── networkpolicy.yaml
│       ├── _helpers.tpl
│       └── tests/
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

### cobblerd
- **NOT PRODUCTION READY**: manually verified with `k3d` + `helm test` (both `httpApi.enabled`
  true/false), which found and fixed three real bugs (missing seed data for `/var/lib/cobbler`,
  no writable `/tmp` for `http-api`, and a Service `targetPort` that silently resolved to zero
  Endpoints when sourced from a sidecar init container) — see the chart's own README "Known
  Limitations" for detail. Not yet run through the real GitHub Actions `ct install` CI pipeline
  with these fixes, and the privileged `cobblerd` container's ISO loop-mount capability is
  unverified.
- **Purpose**: Hosts the Cobbler backend: the `cobblerd` XML-RPC daemon and, by default, its
  companion `http-api` Gunicorn process, as two containers of one Pod sharing one state volume.
- **State**: File-backed (collections, signature cache, webdir, tftproot). `replicaCount` is
  fixed at `1`; the Deployment uses `strategy: Recreate`.
- **Service**: Multi-port `ClusterIP` — `xmlrpc` (25151) always, `http-api` (8000) when
  `httpApi.enabled`.
- **Probes**: `cobblerd` uses an exec TCP-connect check; `http-api` uses `httpGet /healthz`.
- **Important**: `cobblerd` runs `privileged: true`/`runAsUser: 0` by design (ISO loop-mount
  support) — the one chart in this repo that intentionally does not run unprivileged. `http-api`
  runs non-root. Requires Kubernetes >= 1.29 for `http-api`'s native-sidecar startup ordering on
  `cobblerd`. See the chart's own `README.md` "Known Limitations" section for the full rationale.

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

All charts use `_helpers.tpl` for consistent naming, e.g. for `cobblerd`:
- `cobblerd.fullname`: Full resource name
- `cobblerd.name`: Chart name
- `cobblerd.chart`: Chart label
- `cobblerd.labels`: Common labels
- `cobblerd.selectorLabels`: Selector labels
- `cobblerd.serviceAccountName`: Service account name
- `cobblerd.pvcName`: PVC name (chart-managed or `persistence.existingClaim`)
- `cobblerd.cobblerdVolumeMounts`: Shared volumeMounts for the `cobblerd` container, used whether
  it's the sole container or the `http-api`-gating sidecar initContainer

The same pattern (`<chart-name>.fullname`, `.name`, `.chart`, `.labels`, `.selectorLabels`,
`.serviceAccountName`) applies to `cobbler-web`/`cobbler-tftp`/etc.

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