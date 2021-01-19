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
The default Rocket URL is http://public.kubernetes.stratio.com/discovery-demo/
Add public.kubernetes.stratio.com to /etc/hosts, using the address returned by the 'kubectl get nodes -o wide' command in nodes with role NONE.

```shell
kubectl apply -f discovery-ingress.yml
kubectl get ingress
```

