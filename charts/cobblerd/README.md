# cobblerd

**NOT PRODUCTION READY.** This chart is new. It has been installed and `helm test`-ed end-to-end
against a real `k3d` cluster (both with and without `httpApi.enabled`) — see "Known Limitations"
below for what that run found and fixed, and for what is still unverified (in particular, the
privileged `cobblerd` container's ISO loop-mount capability, the actual reason it needs to run
privileged at all) — before relying on this chart for anything beyond evaluation.

A Helm chart to deploy the Cobbler backend to Kubernetes: the `cobblerd` XML-RPC daemon (owns all
distro/profile/system/etc. state) and, by default, its companion HTTP/XML-RPC API (`http-api`,
Gunicorn serving `cobbler.services:application` — templated kickstart/preseed delivery,
`/httpboot`, `/images`, `/sso_login`). Both run as two containers of one Pod, sharing the same
`ghcr.io/cobbler/cobblerd` image and the same state volume.

## Scope

This chart covers the Cobbler backend only. The following are separate, independently installed
charts in this repository, or out of scope entirely:

- [`cobbler-web`](../cobbler-web) — the Web UI frontend.
- [`cobbler-tftp`](../cobbler-tftp) — the TFTP server.
- [`cobbler-http-sd`](../cobbler-http-sd) — a Prometheus service-discovery adapter.
- DHCP/DNS sidecars have no chart here at all: serving real DHCP clients needs L2 broadcast access
  a Kubernetes Service cannot provide, and see "Known Limitations" below for a second,
  independent reason not to run them alongside this chart today.

## Known Limitations

- **Not production ready.** A manual `k3d` install + `helm test` run found and fixed three real
  bugs that `helm lint`/`helm template`/`kube-linter` alone did not catch: (1) cobblerd failed to
  start at all (`FileNotFoundError: /var/lib/cobbler/distro_signatures.json`) because Kubernetes
  volumes, unlike Docker named volumes, are never seeded from the image's own content at a mount
  point — fixed with a `seed-data` init container; (2) `http-api` crash-looped
  (`FileNotFoundError: No usable temporary directory`) because its `readOnlyRootFilesystem: true`
  left no writable `/tmp` for Gunicorn — fixed with a dedicated `emptyDir` mounted at `/tmp`; (3)
  the Service's `xmlrpc` port resolved to zero Endpoints because, when `httpApi.enabled`,
  `cobblerd` runs as a native-sidecar *init* container, and this cluster's (k3s v1.31.5) Endpoints
  controller does not resolve a named `targetPort` against init-container ports — fixed by
  targeting that port by number instead. What's still unverified: the privileged `cobblerd`
  container's ISO loop-mount capability (the actual reason it needs to run privileged at all), and
  a run through the real GitHub Actions `ct install` CI pipeline with these fixes applied.
- **Cobbler cannot signal or restart DHCP/DNS/TFTP sidecar Pods in Kubernetes.** In Docker
  Compose, `modules.process_management.module: "docker"` lets `cobblerd` restart/signal those
  sidecar *containers* via the Docker socket whenever a trigger regenerates their config. There is
  no Kubernetes equivalent wired up today. This chart therefore ships with `manage_tftpd`,
  `manage_dhcp_v4`, `manage_dhcp_v6`, and `manage_dns` all disabled by default (see
  `values.yaml`'s `settings` block) — turning any of them on will make `cobblerd` write
  configuration files that no running service will ever reload without a manual restart.
- **Requires Kubernetes >= 1.29.** `cobblerd` runs as a native sidecar container
  (`initContainers` entry with `restartPolicy: Always` and a `startupProbe`), which Kubernetes
  only stably supports from 1.29 onward. This is what makes `http-api` wait for `cobblerd` to be
  reachable before it starts, mirroring Docker Compose's
  `depends_on: cobblerd: condition: service_healthy`.
- **The `cobblerd` container runs privileged, as root, by design.** Cobbler needs real root (for
  example, loop-mounting an ISO during `cobbler import`), which cannot be granted safely or
  reliably to a non-root/unprivileged Pod. This is a deliberate deviation from every other chart
  in this repository, all of which run unprivileged. If you deploy this chart into a
  Pod-Security-restricted namespace, you will need to grant an exemption for this specific
  workload — it is not a bug or an oversight. The `http-api` container, which only serves
  already-built files, keeps a conventional non-root `securityContext`.
- `cobblerd` is a singleton: `replicaCount` only exists for consistency with this repository's
  other charts and is not safe to change above `1` (its state is file-backed behind a single
  volume, and a rolling update briefly running two replicas against it is unsafe — hence the
  Deployment's `Recreate` strategy).
- **Default authorization is `authorization.allowall` on an XML-RPC port bound to `0.0.0.0`.**
  Combined with a privileged, root container, this means every XML-RPC method — including
  state-mutating ones — is reachable with no access control from anywhere the Service/
  `networkPolicy` allows, which by default is the whole cluster network. This mirrors Cobbler's
  own Docker Compose reference stack so the chart works out of the box, but it is not an
  acceptable default for a shared or multi-tenant cluster. Before any non-evaluation use: switch
  `settings.modules.authorization.module` to a real backend with an explicit admin list and
  provision real credentials (mount a custom `/etc/cobbler/users.digest` via the `volumes`/
  `volumeMounts` values), and enable `networkPolicy` below to narrow who can reach port 25151 at
  all.
- `networkPolicy.enabled` is `false` by default: this chart cannot know your cluster's topology
  (e.g. which namespace `cobbler-web`/`cobbler-tftp` run in), so a default-enabled policy would
  either break legitimate cross-component access or be too permissive to matter. Set
  `networkPolicy.enabled: true` and fill in `networkPolicy.ingress` (raw `NetworkPolicyIngressRule`
  entries) for your own topology — strongly recommended given the point above.

## Installing the Chart

```bash
helm install cobblerd cobbler/cobblerd
```

For a real deployment, also enable persistence so `cobblerd`'s state survives Pod restarts:

```bash
helm install cobblerd cobbler/cobblerd \
  --set persistence.enabled=true \
  --set persistence.size=20Gi
```

## Values

| Key | Default | Description |
|---|---|---|
| `image.repository` / `image.tag` | `ghcr.io/cobbler/cobblerd` / chart `appVersion` | Shared image for both the `cobblerd` and `http-api` containers; the role is selected by `command:`, not the image. |
| `httpApi.enabled` | `true` | Also runs the Gunicorn `http-api` container alongside `cobblerd`. Set to `false` to deploy the bare XML-RPC daemon on its own. |
| `cobblerd.securityContext` | `privileged: true`, `runAsUser: 0` | See "Known Limitations" — do not change without verifying ISO import/buildiso workflows still work. |
| `httpApi.securityContext` | non-root, `runAsUser: 1000` | `http-api` performs no ISO/mount operations and keeps a conventional profile. |
| `service.xmlrpcPort` / `service.httpApiPort` | `25151` / `8000` | Ports the Service exposes for each role. |
| `settings` | mirrors `docker/compose/base.yml`'s `cobbler-settings` | Rendered verbatim into the ConfigMap's `settings.yaml` key — override any Cobbler setting here. |
| `logging.level` | `INFO` | Rendered into the ConfigMap's `logging_config.conf` (stdout-only handler). |
| `persistence.enabled` | `false` (ephemeral `emptyDir`) | Set `true` (and optionally `persistence.storageClassName`/`persistence.size`) for a real deployment. `persistence.existingClaim` lets you supply your own PVC instead. |
| `volumes` / `volumeMounts` | `[]` | Passthrough for e.g. mounting a custom `/etc/cobbler/users.digest` Secret — this chart ships no auth/credential management of its own, since the health/test probes (`ping()`, `/healthz`) need none. |
| `ingress.enabled` | `false` | Only takes effect when `httpApi.enabled` is also `true`. Routes `/cblr`, `/httpboot`, `/images`, `/sso_login`. |
| `networkPolicy.enabled` / `networkPolicy.ingress` | `false` / `[]` | See "Known Limitations" — recommended hardening for the `authorization.allowall` default; fill in `ingress` for your own cluster topology. |
