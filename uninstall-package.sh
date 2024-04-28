#!/usr/bin/env bash
set -eo pipefail

# Uninstalls one or more Tanzu package(s) via kapp and kubectl CLIs
## Packages must conform to a specific directory structure
## +- application_name
##   +- .init
##   +- .install
##   +- base

## Do not change anything below unless you know what you're doing!

# Delete applications and associated configurations
delete_applications() {
  local gitops_dir=$1
  local app_name=$2
  local ytt_parent_dir=$3

  # Handle ancillary applications
  handle_ancillary "$gitops_dir" "$app_name" "$ytt_parent_dir"

  # Delete main app and RBAC
  if [ -d "$gitops_dir/.init" ] && [ -d "$gitops_dir/.install" ]; then
    kapp delete --app $app_name --diff-changes --yes
    kapp delete --app $app_name-ns-rbac --diff-changes --yes
  else
    echo "Expected to find .init and .install directories."
    exit 1
  fi

  # Handle pre-requisites
  if [ -d "$gitops_dir/.prereq" ]; then
    kubectl delete -f $gitops_dir/.prereq
  fi
}

# Handle ancillary applications based on .post-install configurations
handle_ancillary() {
  local dir=$1
  local app_name=$2
  local working_dir=$3

  if [ -d "$dir/.post-install" ]; then
    local files=$(find "$dir/.post-install" -type f -name "*.yml" | wc -l)
    if [ $files -eq 1 ]; then
      local kind=$(yq e '.kind' $dir/.post-install/*.yml)
      if [ "$kind" == "App" ]; then
        local ytt_paths=( $(yq e '.spec.template.[].ytt.paths.[]' $dir/.post-install/*.yml) )
        local i=0
        for ytt_path in "${ytt_paths[@]}"
        do
          if [[ "$working_dir" == *"${ytt_path}"* ]]; then
              local prefix = "${working_dir/$ytt_path/}"
              local detected_path = "${GITHUB_WORKSPACE}/${prefix}/${ytt_path}"
          else
              local detected_path = "${GITHUB_WORKSPACE}/${ytt_path}"
          fi
          if [ -d "${detected_path}" ]; then
              i=$((i+1))
          fi
        done
        if [ $i -gt 0 ] && [ $i -eq ${#ytt_paths[@]} ]; then
          kapp delete --app $app_name-ancillary --diff-changes --yes
        fi
      fi
    fi
  fi
}

if [ "x${KUBECONFIG}" == "x" ]; then
  echo "Workload cluster KUBECONFIG environment variable not set."

  if [ -z "$1" ]; then
    echo "Workload cluster name was not supplied!"
	  exit 1
  fi

  if [ -z "$2" ]; then
    echo "Management cluster's KUBECONFIG base64-encoded contents was not supplied!"
	  exit 1
  fi

  WORKLOAD_CLUSTER_NAME="$1"

  echo "- Decoding the management cluster's KUBECONFIG contents and saving output to /tmp/.kube-tkg/config"
  mkdir -p /tmp/.kube-tkg
  echo "$2" | base64 -d > /tmp/.kube-tkg/config
  chmod 600 /tmp/.kube-tkg/config

  cluster_name=$(cat /tmp/.kube-tkg/config | yq '.clusters[].name')
  echo "- Management cluster name is [ $cluster_name ]"

  echo "- Logging in to management cluster"
  tanzu login --kubeconfig /tmp/.kube-tkg/config --context ${cluster_name}-admin@${cluster_name} --name ${cluster_name}

  echo "- Obtaining the workload cluster's KUBECONFIG and setting the current context for kubectl"
  tanzu cluster kubeconfig get ${WORKLOAD_CLUSTER_NAME} --admin
  kubectl config use-context ${WORKLOAD_CLUSTER_NAME}-admin@${WORKLOAD_CLUSTER_NAME}

  if [ -z "$4" ]; then
    echo "Application name was not supplied!"
    exit 1

  else
    if [ -z "$3" ]; then
      echo "Path to Tanzu package was not supplied!"
      exit 1

    else
      GITOPS_DIR=$GITHUB_WORKSPACE/$3
      APP_NAME="${4}"
      cd ${GITOPS_DIR}

      delete_applications "$GITOPS_DIR" "$APP_NAME" "$3"
    fi
  fi

else
  echo "Workload cluster KUBECONFIG environment variable was set."

  if [ -z "$2" ]; then
    echo "Application name was not supplied!"
    exit 1

  else
    if [ -z "$1" ]; then
      echo "Path to Tanzu package was not supplied!"
      exit 1

    else
      GITOPS_DIR=$GITHUB_WORKSPACE/$1
      APP_NAME="${2}"
      cd ${GITOPS_DIR}

      delete_applications "$GITOPS_DIR" "$APP_NAME" "$1"
    fi
  fi

fi
