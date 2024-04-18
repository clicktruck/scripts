#!/usr/bin/env bash
set -eo pipefail

## Deletes workloads from one or more namespaces using tanzu CLI

## Do not change anything below unless you know what you're doing!

if [ -z "$1" ]; then
  echo "Namespaces were not supplied!"
  exit 1

else
  namespaces="$1"
  IFS=',' read -ra ns_array <<< "$namespaces"
  for ns in "${ns_array[@]}"
  do
    echo "Does namespace exist?"
    kubectl get namespace $ns
    echo "Are there any workloads and/or deliverables in namespace [ $ns ]?"
    kubectl get workload,deliverable --namespace $ns
    echo "Attempting to delete workloads in namespace [ $ns ]..."
    tanzu apps workload delete --all --namespace $ns --yes
  done
fi
