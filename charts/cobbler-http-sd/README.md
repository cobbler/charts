# cobbler-http-sd

A Helm chart to deploy
[`cobbler-http-sd`](https://github.com/openSUSE/orthos2/tree/master/docker/cobbler-http-sd), a
Prometheus [HTTP service discovery](https://prometheus.io/docs/prometheus/latest/http_sd/)
adapter for Cobbler, to Kubernetes.

It replaces manually regenerating a static Prometheus target list from Cobbler: this service
queries the configured Cobbler servers' `get_systems()` on demand (cached briefly) and serves the
current set of targets — both the `default` (host) and `bmc` interface of every system — on
`GET /sd`. It is internal-only: nothing in this chart exposes it outside the cluster, since it's
meant to be queried by Prometheus's `http_sd_configs` over the cluster network.

## Prerequisites

- A Secret containing the `servers.json` payload described below, provisioned **out-of-band**
  (this chart intentionally does not accept real Cobbler credentials as Helm values — see step 1).

## Installing the Chart

Run the following from the root of this chart (`charts/cobbler-http-sd/` in the
[cobbler/charts](https://github.com/cobbler/charts) repository).

### 1. Create the Secret

Create a `servers.json` file listing the Cobbler servers to query. Each entry needs a `url` (the
Cobbler XML-RPC endpoint) and may optionally carry `username`/`password` for servers that require
authentication; entries without credentials are queried anonymously:

```json
[
  {"url": "http://cobbler.example.org/cobbler_api", "username": "changeme", "password": "changeme"}
]
```

Then create the Secret directly against the cluster (do not commit this file to git):

```bash
kubectl create secret generic cobbler-http-sd-credentials \
  --namespace [namespace] \
  --from-file=servers.json=./servers.json
```

### 2. Install the chart

```bash
helm install cobbler-http-sd . \
  --namespace [namespace] \
  --set configSecretName=cobbler-http-sd-credentials
```

## Values

| Key | Default | Description |
|---|---|---|
| `image.repository` | `registry.opensuse.org/systemsmanagement/orthos2/containers/cobbler-http-sd` | Container image, built via OBS from the `orthos2` repo's `docker/cobbler-http-sd/`. |
| `image.tag` | chart `appVersion` (`1.22`) | Use `"next"` for the staging/testing build variant instead. |
| `env.cacheTtlSeconds` | `300` | How long a built target list is served before Cobbler is queried again. |
| `configSecretName` | `""` | Name of the externally-provisioned Secret carrying `servers.json` (step 1 above). Ignored when `secrets.create` is true. |
| `secrets.create` / `secrets.serversJson` | `false` / `"[]"` | Lets the chart template its own Secret instead - only intended for `ct install`/CI, never for a real deployment. |
| `service.port` | `8080` | Port the adapter listens on and the Service exposes. |
