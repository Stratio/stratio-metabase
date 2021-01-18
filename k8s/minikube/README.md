# How-to deploy discovery on Kubernetes (Minikube)

## Overview

TODO

## Prerequisites

1. Kubernetes cluster
   You can create a local cluster using [minikube](https://kubernetes.io/docs/tasks/tools/install-minikube/).

   Once installed, create the cluster and install internal kubectl
   ```shell
   minikube start --driver=docker --cpus 8 --memory 12g --feature-gates=TTLAfterFinished=true --disk-size=50GB --kubernetes-version=1.18.10
   minikube kubectl -- get pods -A
   minikube dashboard
   ```

   or use VirtualBox driver
   ```shell
   minikube start --driver=virtualbox --cpus 8 --memory 12g --feature-gates=TTLAfterFinished=true --disk-size=50GB --kubernetes-version=1.18.10
   minikube kubectl -- get pods -A
   minikube dashboard
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
   These services can run inside or outside the cluster.

   a) Inside the cluster

   TODO

   b) Outside the cluster

   If you already have instances of these services accessible from your cluster (i.e docker containers in your localhost),
   you can create a [service without selector](external/postgres-service.yaml) and set an [endpoint object](external/postgres-endpoint.yaml)
   to route the service to your specific endpoint. After editing them apply the changes.

   ```shell
   kubectl apply -f external/postgres-service.yaml
   kubectl apply -f external/postgres-endpoint.yaml
    ```

   It is required a database, schema and user in database (Postgres). So, you need run this sentences in your local postgres service:
    ```roomsql
   -- Connect with postgres
    CREATE USER discovery SUPERUSER INHERIT CREATEDB CREATEROLE REPLICATION;

    -- Connect with discovery user
    CREATE DATABASE discovery;
    CREATE SCHEMA discovery;
    GRANT CONNECT ON DATABASE discovery to discovery;
    ```

   Optionally, you can add hdfs service to be able to use Crossdata Driver

   ```shell
   kubectl apply -f external/hdfsservice.yml
   kubectl apply -f external/hdfsendpoint.yml
   ```

   To create an image of hdfs exposing hadoop config files you may run these commands:

   if minikube is deployed with virtualbox, is mandatory to deploy hdfs inside the cluster, you need to change de default docker server before
   ```shell
   eval $(minikube docker-env)
   ```

   ```shell
   cd minikube/external
   docker build --tag hdfswithconfigserver:0.1 -f DockerfileHDFS .
   docker run --entrypoint "/hdfs-entrypoint.sh" --rm -p 9000:9000 -p 19191:19191 -p 50070:50070 hdfswithconfigserver:0.1
   cd -
   ```


## Deploy Discovery

[Edit](./discovery-deployment.yaml) the docker image and apply the service & deployment.
```shell
kubectl apply -f discovery-config.yaml
kubectl apply -f discovery-deployment.yaml
kubectl apply -f discovery-service.yaml
```

Once the pods & service are up and running you can access via node public IP and specified nodePort (30009)
With minikube, run this command to get the URL:
```shell
minikube service -n ns-discovery discovery-demo --url
```

### Expose via Ingress

If you are using minikube, enable ingress addon:

```shell
minikube addons enable ingress
```

The hostname and path used to expose Discovery are define by the [Ingress descriptor](minikube/discovery-ingress.yaml)
The default Discovery URL is http://public.kubernetes.stratio.com/discovery/. Add public.kubernetes.stratio.com to /etc/hosts,
using the address returned by the 'kubectl get ingress' command.

```shell
kubectl apply -f discovery-ingress.yaml
kubectl get ingress
```

## Access Discovery

Access to Discovery through the link:
```
http://public.kubernetes.stratio.com/discovery/
```

In order to import/export collection, you need a metabase header created in dscovery application: ``metabase.SESSION``.
For instance, if metabase.SESSION is equals to 95adea5a-ecef-41e5-beaf-e670ced36128:
```shell
curl http://public.kubernetes.stratio.com/discovery/discovery-cicd/export/1 -H 'x-metabase-session: 95adea5a-ecef-41e5-beaf-e670ced36128' --insecure | jq

curl http://public.kubernetes.stratio.com/discovery/discovery-cicd/import -H 'Content-Type: application/json' -H 'x-metabase-session: 95adea5a-ecef-41e5-beaf-e670ced36128' -d @coleccion.json --insecure
```
