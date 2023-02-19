# rancher-demo

Rancher k8s ControlPlane + k8s Application Lifecycle Demo

This demo creates a Management cluster via [KinD](https://kind.sigs.k8s.io/) and installs [Rancher](https://ranchermanager.docs.rancher.com/) in it.
Then creates 4 other Member clusters (qa, cicd, data, prod) and joins them to the Management cluster via [Rancher Fleet](https://fleet.rancher.io/).

```text
              mgmt
  _____________|_____________
 /        /        \         \
qa      cicd      data      prod
```

## Requirements

Tested on:

- 6 CPU allocated to docker
- 32GB allocated to docker
- 500GB SSD allocated to docker

## Start Management and Member clusters

```shell
./run-rancher-demo.sh
```

Wait for a while and the browser should open the local demo **Rancher dashboard** at `https://localhost:8443/`

## Install Fleet Agent on Member clusters to join Management cluster

```shell
./run-rancher-demo.sh join
```

When the [Rancher Fleet Agent](https://fleet.rancher.io/agent-initiated) joins to the Management cluster, the Fleet Manager will reconcile the [GitRepo](https://fleet.rancher.io/gitrepo-add) objects and install some [Helm](https://helm.sh/) charts to the Member clusters depending on the [ClusterGroup](https://fleet.rancher.io/cluster-group) they are part of. You can view the **Rancher dashboard** under **Continuous Delivery** to inspect the `GitRepo`, `Cluster`, `ClusterGroup`.

## Delete Management and Member clusters

Use this to clean up the clusters.

```shell
./run-rancher-demo.sh delete
```
