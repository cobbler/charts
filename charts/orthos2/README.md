# orthos2

A Helm chart to deploy [Orthos2](https://github.com/openSUSE/orthos2), SUSE's machine
administration tool, to Kubernetes.

This chart deploys three workloads built from the same `orthos2` container image plus a static
asset server:

- **web** — the Orthos2 web UI and API (gunicorn), exposed via the `orthos2` Service on port 8000.
- **taskmanager** — background task processing (machine scans, reboots, Cobbler/Netbox sync,
  etc.). Always runs as a single replica; never exposed via a Service.
- **static** — an nginx container serving Orthos2's static assets, exposed via the
  `orthos2-static` Service on port 80.

## Prerequisites

- An external, already-running Postgres database. This chart does not deploy one — Orthos2 web
  and taskmanager pods each need `ORTHOS2_DB_ENGINE`/`ORTHOS2_POSTGRES_*` configured (see step 3
  below), or they silently fall back to a local, per-pod, non-persistent SQLite file.
- (Optional) An SSH private key and client config if you want the taskmanager to manage machines
  over SSH (see step 4 below).

## Installing the Chart

Run the following from the root of this chart (`charts/orthos2/` in the
[cobbler/charts](https://github.com/cobbler/charts) repository).

### 1. Create a namespace (optional)

It's recommended you create a namespace for this project using

```bash
kubectl create namespace [namespace]
```

### 2. Create the Secret

Create a secret named `orthos2` in its namespace, containing the Netbox Token, the OIDC Secret,
the Orthos Key, and the Postgres password for the external database (see step 3)

```bash
kubectl create secret generic orthos2 \
    --from-literal=NetboxToken=[Netbox Token here] \
    --from-literal=OIDCsecret=[OIDC Secret here] \
    --from-literal=OrthosKey=[Orthos Key here] \
    --from-literal=OrthosPostgresPassword=[Postgres password here] \
    --namespace=[Namespace]
```

### 3. Create Environment Variables

Create a ConfigMap named `orthos2-env`. This is most easily done by making an env file using
`.env.example` (in this chart's root) and executing this command:

```bash
kubectl create configmap orthos2-env \
    --from-env-file=.env \
    --namespace=[Namespace]
```

Orthos2 requires an external, already-running Postgres database — this chart does not deploy one.
Set `ORTHOS2_DB_ENGINE` (e.g. `django.db.backends.postgresql`), `ORTHOS2_POSTGRES_HOST`,
`ORTHOS2_POSTGRES_PORT`, `ORTHOS2_POSTGRES_NAME`, and `ORTHOS2_POSTGRES_USER` in the `.env` file
before creating the ConfigMap. The database password is not part of this ConfigMap — it comes from
the `OrthosPostgresPassword` key of the `orthos2` Secret created in step 2. Leaving
`ORTHOS2_DB_ENGINE` unset makes Orthos2 silently fall back to a local, per-pod SQLite file that is
not shared between the web and taskmanager pods and is lost on every pod restart.

### 4. Create the SSH Secret for the taskmanager (optional, required for managing machines over SSH)

The taskmanager pod uses SSH (via Paramiko) to reach managed machines. Create a Secret containing
an SSH client `config` file (and any private key files it references via `IdentityFile`), then
point the chart at it via `sshSecretName` in `values.yaml` (or `--set sshSecretName=orthos2-ssh`):

```bash
kubectl create secret generic orthos2-ssh \
    --from-file=config=[path to ssh config] \
    --from-file=id_rsa=[path to private key] \
    --namespace=[Namespace]
```

This is mounted read-only at `/var/lib/orthos2/.ssh` in the taskmanager pod only (not the web or
static pods), matching `$HOME/.ssh` as read by `orthos2/utils/ssh.py`.

### 5. Install the chart

```bash
helm install orthos2 .
```

### Alternative: let the chart manage the Secret/ConfigMap (CI/dev only)

Steps 2 and 3 can be skipped by setting `secrets.create: true` (with `secrets.netboxToken`,
`secrets.oidcSecret`, `secrets.orthosKey`, `secrets.postgresPassword`) and populating `env` in
`values.yaml`/`--set`/`-f` instead — the chart will then template the `orthos2` Secret and
`orthos2-env` ConfigMap itself. This is how `charts/orthos2/ci/test-values.yaml` bootstraps the
chart for `ct install` in CI without any orthos2-specific steps in the shared lint-test.yml
workflow. Avoid this for real deployments: the values end up stored in plaintext in your Helm
release.
