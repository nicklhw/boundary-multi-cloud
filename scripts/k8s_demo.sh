#!/usr/bin/env bash

# https://www.hashicorp.com/blog/how-to-connect-to-kubernetes-clusters-using-boundary

#set -v

source ./scripts/k8s_context.sh

tput setaf 12 && echo "### Running Nginx pod ###" && tput sgr0

if kubectl get pods | grep -q nginx; then
  echo "nginx pod already running."
else
  echo "Running nginx pod..."

  kubectl run nginx --image=nginx

  while [[ $(kubectl get pods nginx -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]];
  do
    echo "Waiting for pod to be ready..." && sleep 1;
  done
fi

tput setaf 12 && echo "### Getting Nginx pod ###" && tput sgr0

kubectl get pod nginx

#kubectl delete pod nginx



