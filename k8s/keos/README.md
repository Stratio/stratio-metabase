# How-to deploy discovery on Kubernetes(whiskey)

## Overview

TODO

## Prerequisites

1. Kubernetes cluster
   You need to edit your .kube/config file and add the cluster configuration.

   After edited k8s config file you need to change the context
   ```shell
   kubectl config use-context kubernetes-admin@whiskey.hetzner
   ```

   Create a Discovery namespace
   ```shell
   kubectl apply -f ns-discovery.json
   ```
   Switch to discovery namespace by default
   ```shell
   kubectl config set-context --current --namespace=ns-discovery
   ```

2. External services
   Discovery requires some services up and running: PostgreSQL and HDFS (only required to some features).
   Temporarily, deploy your own postgres service:
    ```shell
    kubectl apply -f temporal/postgres-storage.yaml
    kubectl apply -f temporal/postgres-deployment.yaml
    kubectl apply -f temporal/postgres-service.yaml
    ```

   It is required a database, schema and user in database (Postgres). As at the moment CCT does not execute prerequisites you will have to run this sentences in your postgres service:
    ```roomsql
   -- Connect with postgres
    CREATE USER discovery SUPERUSER INHERIT CREATEDB CREATEROLE REPLICATION;

    -- Connect with discovery user
    CREATE DATABASE discovery;
    CREATE SCHEMA discovery;
    GRANT CONNECT ON DATABASE discovery to discovery;
    ```


## Deploy Rocket

[Edit](./discovery-deployment.yaml) the docker image and apply the service & deployment.
```shell
kubectl apply -f discovery-config.yaml
kubectl apply -f discovery-deployment.yaml
kubectl apply -f discovery-service.yaml
```

The hostname and path used to expose Discovery are define by the [Ingress descriptor](./rocket-ingress.yml)
The default Rocket URL is http://public.whiskey.kubernetes.stratio.com/discovery/
Add public.whiskey.kubernetes.stratio.com to /etc/hosts, using the address returned by the 'kubectl get nodes -o wide' command in nodes with role NONE.

```shell
kubectl apply -f discovery-ingress.yaml
kubectl get ingress
```

## Access Discovery

Access to Discovery through the link:
```
http://public.whiskey.kubernetes.stratio.com/discovery/
```

In order to import/export collection, you need a metabase header created in dscovery application: ``metabase.SESSION``.
For instance, if metabase.SESSION is equals to 95adea5a-ecef-41e5-beaf-e670ced36128:
```shell
curl http://public.whiskey.kubernetes.stratio.com/discovery/discovery-cicd/export/1 -H 'x-metabase-session: 95adea5a-ecef-41e5-beaf-e670ced36128' --insecure | jq

curl http://public.whiskey.kubernetes.stratio.com/discovery/discovery-cicd/import -H 'Content-Type: application/json' -H 'x-metabase-session: 95adea5a-ecef-41e5-beaf-e670ced36128' -d @coleccion.json --insecure
```

