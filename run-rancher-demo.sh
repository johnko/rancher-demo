#!/bin/bash

#####################################################################
# This `run-rancher-demo.sh` script will create a demo
# k8s-in-docker cluster and install Rancher with Helm.
#
# You can then log in to the Rancher local demo UI and
# install Apps (Helm Charts) via the Rancher interface.
#
# Caveat: no gitops out of the box for rancher itself,
#         can use Rancher Fleet to bootstrap clusters,
#         and install ArgoCD and sync with a git repo.
#
# Based on instructions from:
# https://ranchermanager.docs.rancher.com/getting-started/quick-start-guides/deploy-rancher-manager/helm-cli
#####################################################################

set -e

create_kind_cluster() {
  # image from https://github.com/kubernetes-sigs/kind/releases
  # kind create cluster --config kind-2-node.yaml \
  kind create cluster \
    --image kindest/node:v1.24.7@sha256:577c630ce8e509131eab1aea12c022190978dd2f745aac5eb1fe65c0807eb315 \
    --name $1
}
delete_kind_cluster() {
  kind delete cluster \
    --name $1
}
install_fleet_agent() {
  # https://rancher.github.io/fleet/agent-initiated/
  CLUSTER_LABELS="$2"
  CLUSTER_CLIENT_ID="kind-$1"
  API_SERVER_URL=$(kubectl config view --context $MGMT_CONTEXT --minify --output jsonpath='{.clusters[*].cluster.server}' | sed 's/127.0.0.1/mgmt-control-plane/')
  API_SERVER_CA=$(kubectl config view --context $MGMT_CONTEXT --minify --raw -o go-template='{{index ((index (index .clusters 0) "cluster")) "certificate-authority-data"|base64decode}}')
  kubectl config use-context $CLUSTER_CLIENT_ID
  # curl -L -O https://github.com/rancher/fleet/releases/download/v0.5.1/fleet-agent-0.5.1.tgz
  helm -n cattle-fleet-system upgrade --atomic --install --create-namespace --wait \
    ${CLUSTER_LABELS} \
    --set-string labels.env=demo \
    --set clientID="${CLUSTER_CLIENT_ID}" \
    --values values.yaml \
    --set apiServerCA="${API_SERVER_CA}" \
    --set apiServerURL="${API_SERVER_URL}" \
    fleet-agent ./helm-charts/fleet-agent
}
MGMT_CLUSTER="mgmt"
set -u
MGMT_CONTEXT="kind-$MGMT_CLUSTER"
MGMT_KUBECTL="kubectl --context $MGMT_CONTEXT"
TEAM_CLUSTERS="
cicd
qa
data
prod
"
set +u
if [ "delete" == "$1" ]; then
  set -u
  for i in $MGMT_CLUSTER $TEAM_CLUSTERS; do
    delete_kind_cluster $i
  done
  exit 0
fi
if [ "join" == "$1" ]; then
  set -u
  $MGMT_KUBECTL -n fleet-default get secret demo-token -o 'jsonpath={.data.values}' | base64 --decode > values.yaml
  for i in $TEAM_CLUSTERS; do
    install_fleet_agent $i "${prod_label} ${batch_label}"
  done
  exit 0
fi

set -ux

create_kind_cluster $MGMT_CLUSTER
kubectl config use-context $MGMT_CONTEXT
$MGMT_KUBECTL create namespace cattle-system
# mkdir -p ./crds
# curl -L -o ./crds/cert-manager.crds.yaml https://github.com/cert-manager/cert-manager/releases/download/v1.7.1/cert-manager.crds.yaml
$MGMT_KUBECTL apply -f ./crds/cert-manager.crds.yaml
# helm repo add rancher-latest https://releases.rancher.com/server-charts/latest
# helm repo add jetstack https://charts.jetstack.io
# helm repo update
# mkdir -p ./helm-charts
# pushd ./helm-charts
# helm pull --untar jetstack/cert-manager --version v1.7.1
# popd
helm install cert-manager ./helm-charts/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.7.1
PASSWORD_FOR_RANCHER_ADMIN=$( cat /dev/random | LC_ALL=C tr -dc 'a-zA-Z0-9-_' | fold -w 30 | head -n 1 )
# pushd ./helm-charts
# helm pull --untar rancher-latest/rancher
# popd
helm install rancher ./helm-charts/rancher \
  --namespace cattle-system \
  --set hostname=127.0.0.1.sslip.io \
  --set replicas=1 \
  --set bootstrapPassword="$PASSWORD_FOR_RANCHER_ADMIN"
# $MGMT_KUBECTL get secret --namespace cattle-system bootstrap-secret \
#   -o go-template='{{.data.bootstrapPassword|base64decode}}{{ "\n" }}'

for i in $TEAM_CLUSTERS; do
  create_kind_cluster $i
done

$MGMT_KUBECTL -n fleet-local patch clusters.fleet.cattle.io local --type merge --patch '{"metadata":{"labels":{"env":"mgmt"}}}'
$MGMT_KUBECTL apply -f ./demo.yaml
set +x
echo "Use this password to login to Rancher local demo UI: $PASSWORD_FOR_RANCHER_ADMIN"
open "https://localhost:8443/"
for i in $(seq 1 10); do
  for pauser in $(seq 1 30); do
    echo -n '.'
    sleep 1
  done
  $MGMT_KUBECTL -n cattle-system port-forward svc/rancher 8443:443 || true
done
