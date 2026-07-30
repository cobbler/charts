# Orthos 2 setup

## 1. Create a namespace (Optional)
Its recommended you create a namespace for this project using

```bash
kubectl create namespace [namespace]
```

## 2. Create the Secret
Create a secret named orthos2 in its namespace, containing the Netbox Token, the OIDC Secret, and the Orthos Key

```bash
kubectl create secret generic orthos2 \
    --from-literal=NetboxToken=[Netbox Token here] \
    --from-literal=OIDCsecret=[OIDC Secret here] \
    --from-literal=OrthosKey=[Orthos Key here] \
    --namespace=[Namespace]
```
## 3. Create Environment Variables
Create an Environment Variables named orthos2-env.
This most easily done by making an env file using the env.example in charts/orthos2/configmap/ and executing this command:

```bash
kubectl create configmap orthos2-env \
    --from-env-file=charts/orthos2/configmap/.env \
    --namespace=[Namespace]
```
## 4. Start the pods
The pods can be started using

```bash
helm install orthos2 charts/orthos2/
```
