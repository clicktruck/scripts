#!/usr/bin/env bash
set -eo pipefail

## This script downloads and installs Tanzu Cluster Essentials into a target Kubernetes cluster

## Tanzu Network
## (package configuration)
ESS_VERSION="1.8.1"
export INSTALL_BUNDLE=registry.tanzu.vmware.com/tanzu-cluster-essentials/cluster-essentials-bundle@sha256:46cbfec6658407ede8b882d432f410d2a07e53b8ef167af110e8f5ab191d0f91
export INSTALL_REGISTRY_HOSTNAME=registry.tanzu.vmware.com


## Do not change anything below unless you know what you're doing!

if  [ -z "$1" ] && [ -z "$2" ] && [ -z "$3" ]; then
	echo "Usage: install-tanzu-cluster-essentials.sh {tanzu-network-api-token} {tanzu-network-username} {tanzu-network-password}"
	exit 1
fi

OS="$(uname | tr '[:upper:]' '[:lower:]')"
case $OS in
  darwin)
    echo "Installing MacOS version of Cluster Essentials for VMware Tanzu"
	  ESS_PRODUCT_FILE_ID=1768157
    ;;

  linux)
    echo "Installing Linux version of Cluster Essentials for VMware Tanzu"
	  ESS_PRODUCT_FILE_ID=1768165
    ;;

  *)
    echo "[ Unsupported OS ] cannot install Cluster Essentials for VMware Tanzu"
	exit 1
    ;;
esac

if ! command -v pivnet &> /dev/null
then
    echo "Downloading pivnet CLI..."
	curl -LO https://github.com/pivotal-cf/pivnet-cli/releases/download/v4.1.1/pivnet-linux-amd64-4.1.1
	chmod +x pivnet-linux-amd64-4.1.1
	mv pivnet-linux-amd64-4.1.1 /usr/bin/pivnet
fi

TANZU_NETWORK_API_TOKEN="$1"
TANZU_NETWORK_USERNAME="$2"
TANZU_NETWORK_PASSWORD="$3"

pivnet login --api-token=$TANZU_NETWORK_API_TOKEN

cd /tmp
mkdir -p tanzu-cluster-essentials
pivnet download-product-files --product-slug='tanzu-cluster-essentials' --release-version="${ESS_VERSION}" --product-file-id="${ESS_PRODUCT_FILE_ID}"
tar -xvf tanzu-cluster-essentials-linux-amd64-${ESS_VERSION}.tgz -C tanzu-cluster-essentials

export INSTALL_REGISTRY_USERNAME="${TANZU_NETWORK_USERNAME}"
export INSTALL_REGISTRY_PASSWORD="${TANZU_NETWORK_PASSWORD}"

if [ -z "$4" ] && [ "x$KUBECONFIG" != "x" ]; then
  echo "KUBECONFIG is already set"
else
  mkdir -p /tmp/.kube
  KUBECONFIG_CONTENTS="$4"
  echo "$KUBECONFIG_CONTENTS" | base64 -d > /tmp/.kube/config
  chmod 600 /tmp/.kube/config
  export KUBECONFIG=/tmp/.kube/config
fi

cd tanzu-cluster-essentials
./install.sh --yes
