# charts

To make use of this Helm Repository please execute the following command:

```
helm repo add cobbler https://cobbler.github.io/charts/
```

## Cobbler

At this point in time no Helm Chart is available for the backend.

## Cobbler-Web

This chart will host the Web UI for you. There is no state stored inside the WebUI, as such there is no configuration
to be performed.

```
helm install cobbler/cobbler-web --generate-name
```

## Cobbler-TFTP

At this point in time no Helm Chart is available for the TFTP server.

## Cobbler-HTTP-SD

This chart deploys a Prometheus [HTTP service discovery](https://prometheus.io/docs/prometheus/latest/http_sd/)
adapter for Cobbler: it queries the configured Cobbler servers' `get_systems()` on demand and
serves the current host/BMC targets to Prometheus. It requires a Secret with the Cobbler server
list to be provisioned out-of-band before installing — see the
[chart's README](charts/cobbler-http-sd/README.md) for full instructions.

```
helm install cobbler-http-sd cobbler/cobbler-http-sd --set configSecretName=cobbler-http-sd-credentials
```

## Orthos2

This chart hosts [Orthos2](https://github.com/openSUSE/orthos2), SUSE's machine administration
tool, deploying its web UI, taskmanager, and a static-assets nginx server. Unlike Cobbler-Web, it
requires some manual setup (an external Postgres database and a few Secrets/ConfigMaps) before
installing — see the [chart's README](charts/orthos2/README.md) for full instructions.

```
helm install orthos2 cobbler/orthos2
```
