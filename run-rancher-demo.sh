#!/bin/bash

#####################################################################
# This `run-rancher-demo.sh` script will create a demo
# k8s-in-docker cluster and install Rancher with Helm.
#
# You can then log in to the Rancher local demo UI and
# install Apps (Helm Charts) via the Rancher interface.
#
# Caveat: no gitops out of the box for rancher itself,
#         can install ArgoCD and sync with a git repo.
#
# Based on instructions from:
# https://ranchermanager.docs.rancher.com/getting-started/quick-start-guides/deploy-rancher-manager/helm-cli
#####################################################################

set -eux

# image from https://github.com/kubernetes-sigs/kind/releases
kind create cluster --image kindest/node:v1.24.7@sha256:577c630ce8e509131eab1aea12c022190978dd2f745aac5eb1fe65c0807eb315

kubectl config use-context kind-kind

helm repo add rancher-latest https://releases.rancher.com/server-charts/latest

kubectl create namespace cattle-system

kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.7.1/cert-manager.crds.yaml

helm repo add jetstack https://charts.jetstack.io

helm repo update

helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.7.1

PASSWORD_FOR_RANCHER_ADMIN=$( cat /dev/random | LC_ALL=C tr -dc 'a-zA-Z0-9-_' | fold -w 30 | head -n 1 )

helm install rancher rancher-latest/rancher \
  --namespace cattle-system \
  --set hostname=127.0.0.1.sslip.io \
  --set replicas=1 \
  --set bootstrapPassword="$PASSWORD_FOR_RANCHER_ADMIN"

kubectl get secret --namespace cattle-system bootstrap-secret -o go-template='{{.data.bootstrapPassword|base64decode}}{{ "\n" }}'

open "https://localhost:8443/"

for i in `seq 1 10`; do
  sleep 15
  kubectl -n cattle-system port-forward svc/rancher 8443:443 || true
done

