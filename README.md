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

## Orthos2

This chart hosts [Orthos2](https://github.com/openSUSE/orthos2), SUSE's machine administration
tool, deploying its web UI, taskmanager, and a static-assets nginx server. Unlike Cobbler-Web, it
requires some manual setup (an external Postgres database and a few Secrets/ConfigMaps) before
installing — see the [chart's README](charts/orthos2/README.md) for full instructions.

```
helm install orthos2 cobbler/orthos2
```
