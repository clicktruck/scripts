#!/bin/bash
set -eo pipefail

# Installs one or more Tanzu package(s) via kubectl, kapp and ytt CLIs
## Packages must conform to a specific directory structure
## +- application_name
##   +- .init
##   +- .install
##   +- base

## Do not change anything below unless you know what you're doing!

# Functions

check_required_vars() {
    local desc="$1"
    local var="$2"
    if [ -z "$var" ]; then
        echo "$desc was not supplied!"
        exit 1
    fi
}

decode_kubeconfig() {
    echo "- Decoding the management cluster's KUBECONFIG contents and saving output to /tmp/.kube-tkg/config"
    mkdir -p /tmp/.kube-tkg
    echo "$1" | base64 -d > /tmp/.kube-tkg/config
    chmod 600 /tmp/.kube-tkg/config
}

login_cluster() {
    local config_path="$1"
    local cluster_name=$(cat "$config_path" | yq '.clusters[].name')
    echo "- Logging in to cluster with context ${cluster_name}"
    tanzu login --kubeconfig "$config_path" --context ${cluster_name}-admin@${cluster_name} --name ${cluster_name}
}

apply_directory() {
    local dir="$1"
    local action="$2"
    if [ -d "$dir" ]; then
        echo "- Applying $action in directory $dir"
        kubectl apply -f "$dir"
    fi
}

deploy_app() {
    local dir="$1"
    local app_name="$2"
    if [ -d "${dir}/.init" ] && [ -d "${dir}/.install" ]; then
        kapp deploy --app $app_name-ns-rbac --file <(ytt --file .init) --diff-changes --yes
        kapp deploy --app $app_name --file .install --diff-changes --yes
    else
        echo "Expected to find both .init and .install sub-directories underneath $dir"
        exit 1
    fi
}

handle_post_install() {
    local dir="$1"
    local app_name="$2"
    local working_dir="$3"
    if [ -d "${dir}/.post-install" ]; then
        local files=$(find ${dir}/.post-install -type f -name "*.yml" | wc -l)
        if [ $files -eq 1 ]; then
            local kind=$(yq -o=json '.kind' .post-install/*.yml | tr -d '"')
            if [ "$kind" == "App" ]; then
                local ytt_paths=( $(yq -o=json '.spec.template.[].ytt.paths.[]' .post-install/*.yml | tr -d '"') )
                local ytt_path_count=${#ytt_paths[@]}
                local i=0
                for ytt_path in "${ytt_paths[@]}"
                do
                    if [[ "$working_dir" =~ "$ytt_path" ]]; then
                        local prefix = "${working_dir/$ytt_path/}"
                        local detected_path = "${GITHUB_WORKSPACE}/${prefix}/${ytt_path}"
                    else
                        local detected_path = "${GITHUB_WORKSPACE}/${ytt_path}"
                    fi
                    if [ -d "${detected_path}" ]; then
                        i=$((i+1))
                    fi
                done
                if [ $i -gt 0 ] && [ $i -eq $ytt_path_count ]; then
                    kapp deploy --app $app_name-ancillary --file .post-install --diff-changes --yes
                    local kicks=$(find ${dir}/.post-install -type f -name "kick.sh" | wc -l)
                    if [ $kicks -eq 1 ]; then
                        cd ${dir}/.post-install && ./kick.sh
                    fi
                fi
            fi
        fi
    fi
}

# Main

if [ "x${KUBECONFIG}" == "x" ]; then
    echo "Workload cluster KUBECONFIG environment variable not set."
    check_required_vars "Workload cluster name" "$1"
    check_required_vars "Management cluster's KUBECONFIG base64-encoded contents" "$2"
    WORKLOAD_CLUSTER_NAME="$1"

    decode_kubeconfig "$2"
    login_cluster "/tmp/.kube-tkg/config"
    echo "- Obtaining the workload cluster's KUBECONFIG and setting the current context for kubectl"
    tanzu cluster kubeconfig get ${WORKLOAD_CLUSTER_NAME} --admin
    kubectl config use-context ${WORKLOAD_CLUSTER_NAME}-admin@${WORKLOAD_CLUSTER_NAME}

    check_required_vars "Application name" "$4"
    check_required_vars "Path to Tanzu package" "$3"
    set -x
    GITOPS_DIR="$GITHUB_WORKSPACE/$3"

    cd ${GITOPS_DIR}
    apply_directory ".prereq" "prerequisites"
    deploy_app "${GITOPS_DIR}" "${4}"
    handle_post_install "${GITOPS_DIR}" "${4}" "${3}"
    set +x
else
    echo "Workload cluster KUBECONFIG environment variable was set."
    check_required_vars "Application name" "$2"
    check_required_vars "Path to Tanzu package" "$1"
    set -x
    GITOPS_DIR="$GITHUB_WORKSPACE/$1"

    cd ${GITOPS_DIR}
    apply_directory ".prereq" "prerequisites"
    deploy_app "${GITOPS_DIR}" "${2}"
    handle_post_install "${GITOPS_DIR}" "${2}" "${1}"
    set +x
fi
