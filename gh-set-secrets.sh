#!/usr/bin/env bash

set -eo pipefail

# This script conveniently sets Github Secrets required in order to utilize Github Action workflows in this repo against target clouds.

# Warning - in order to use this script successfully on MacOS, you must install GNU coreutils!
# @see
# * https://github.com/gardener/gardener/issues/7019
# * https://github.com/gardener/gardener/blob/release-v1.60/docs/development/local_setup.md#macos-only-install-gnu-core-utilities


# Sets Github Secrets using environment variables

set_azure_secrets() {
  gh secret set AZURE_SUBSCRIPTION_ID --body "$AZURE_SUBSCRIPTION_ID" --repo "$OWNER/azure-actions"
  gh secret set AZURE_CREDENTIALS --body "$AZURE_CREDENTIALS" --repo "$OWNER/azure-actions"
  gh secret set AZURE_REGION --body "$AZURE_REGION" --repo "$OWNER/azure-actions"
  gh secret set AZURE_AD_TENANT_ID --body "$AZURE_AD_TENANT_ID" --repo "$OWNER/azure-actions"
  gh secret set AZURE_AD_CLIENT_ID --body "$AZURE_AD_CLIENT_ID" --repo "$OWNER/azure-actions"
  gh secret set AZURE_AD_CLIENT_SECRET --body "$AZURE_AD_CLIENT_SECRET" --repo "$OWNER/azure-actions"
}

set_aws_secrets() {
  gh secret set AWS_ACCESS_KEY_ID --body "$AWS_ACCESS_KEY_ID" --repo "$OWNER/aws-actions"
  gh secret set AWS_SECRET_ACCESS_KEY --body "$AWS_SECRET_ACCESS_KEY" --repo "$OWNER/aws-actions"
  if [ x"${AWS_SESSION_TOKEN}" == "x" ]; then
    echo "Session token secret not set."
  else
    gh secret set AWS_SESSION_TOKEN --body "$AWS_SESSION_TOKEN" --repo "$OWNER/aws-actions"
  fi
}

set_google_secrets() {
  gh secret set GOOGLE_PROJECT_ID --body "$GOOGLE_PROJECT_ID" --repo "$OWNER/google-actions"
  gh secret set GOOGLE_SERVICE_ACCOUNT_KEY --body "$GOOGLE_SERVICE_ACCOUNT_KEY" --repo "$OWNER/google-actions"
}

set_oidc_credentials() {
  if [ x"${OIDC_AUTH_PROVIDER}" == "x" ] || [ x"${OIDC_AUTH_CLIENT_ID}" == "x" ] || [ x"${OIDC_AUTH_CLIENT_SECRET}" == "x" ]; then
    echo "Expected OIDC_AUTH_PROVIDER, OIDC_AUTH_CLIENT_ID, and OIDC_AUTH_CLIENT_SECRET environment variables to be set"
    exit 1
  fi
  gh secret set OIDC_AUTH_PROVIDER --body "$OIDC_AUTH_PROVIDER" --repo "$OWNER/$TARGET_CLOUD-actions"
  gh secret set OIDC_AUTH_CLIENT_ID --body "$OIDC_AUTH_CLIENT_ID" --repo "$OWNER/$TARGET_CLOUD-actions"
  gh secret set OIDC_AUTH_CLIENT_SECRET --body "$OIDC_AUTH_CLIENT_SECRET" --repo "$OWNER/$TARGET_CLOUD-actions"
}

set_tanzu_secrets() {
  if [ x"${TANZU_NETWORK_USERNAME}" == "x" ] || [ x"${TANZU_NETWORK_PASSWORD}" == "x" ] || [ x"${TANZU_NETWORK_API_TOKEN}" == "x" ];then
    echo "Expected TANZU_NETWORK_USERNAME, TANZU_NETWORK_PASSWORD, and TANZU_NETWORK_API_TOKEN environment variables to be set"
    exit 1
  fi
  gh secret set TANZU_NETWORK_API_TOKEN --body "$TANZU_NETWORK_API_TOKEN" --repo "$OWNER/$TARGET_CLOUD-actions"
  gh secret set TANZU_NETWORK_USERNAME --body "$TANZU_NETWORK_USERNAME" --repo "$OWNER/$TARGET_CLOUD-actions"
  gh secret set TANZU_NETWORK_PASSWORD --body "$TANZU_NETWORK_PASSWORD" --repo "$OWNER/$TARGET_CLOUD-actions"
}

set_route53_static_credentials() {
  if [ "x${ROUTE53_ZONE_AWS_ACCESS_KEY_ID}" == "x" ] || [ "x${ROUTE53_ZONE_AWS_SECRET_ACCESS_KEY}" == "x" ]; then
    echo "Expected ROUTE53_ZONE_AWS_ACCESS_KEY_ID and ROUTE53_ZONE_AWS_SECRET_ACCESS_KEY environment variables to be set"
    exit 1
  fi
  gh secret set ROUTE53_AWS_ACCESS_KEY_ID --body "$ROUTE53_AWS_ACCESS_KEY_ID" --repo "$OWNER/aws-actions"
  gh secret set ROUTE53_AWS_SECRET_ACCESS_KEY --body "$ROUTE53_AWS_SECRET_ACCESS_KEY" --repo "$OWNER/aws-actions"
}

if [ -z "$1" ]; then
  echo "Usage: ./gh-set-secrets.sh {target-cloud} {owner} {option}"
  echo "  parameters: {target-cloud} is one of [ aws, azure, google ], {owner} is the repository owner or an organization name, and {option} is one of [ --include-oidc-credentials, --include-tanzu-secrets ]"
  echo "  required: {target-cloud}"
  echo "  optional: {owner}, {option}"
  echo "  defaults: {owner} defaults to 'clicktruck', {option} defaults to ''"
  exit 1
fi

TARGET_CLOUD="$1"
OWNER="${2:-clicktruck}"
OPTIONS="$3"

case $TARGET_CLOUD in

  aws)
    if [ x"${AWS_ACCESS_KEY_ID}" == "x" ] || [ x"${AWS_SECRET_ACCESS_KEY}" == "x" ]; then
      echo "Expected AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY environment variables to be set"
      exit 1;
    fi

    set_aws_secrets
    ;;

  azure)
    if [ x"${AZURE_SUBSCRIPTION_ID}" == "x" ] || [ x"${AZURE_AD_TENANT_ID}" == "x" ] || [ x"${AZURE_AD_CLIENT_ID}" == "x" ] || [ x"${AZURE_AD_CLIENT_SECRET}" == "x" ] || [ x"${AZURE_CREDENTIALS}" == "x" ] || [ x"${AZURE_REGION}" == "x" ]; then
      echo "Expected AZURE_SUBSCRIPTION_ID, AZURE_AD_TENANT_ID, AZURE_AD_CLIENT_ID, AZURE_AD_CLIENT_SECRET, AZURE_CREDENTIALS and AZURE_REGION environment variables to be set"
      exit 1;
    fi

    set_azure_secrets
    ;;

  google)
    if [ x"${GOOGLE_PROJECT_ID}" == "x" ] || [ x"${GOOGLE_SERVICE_ACCOUNT_KEY}" == "x" ]; then
      echo "Expected GOOGLE_PROJECT_ID and GOOGLE_SERVICE_ACCOUNT_KEY environment variables to be set"
      exit 1;
    fi

    set_google_secrets
    ;;
esac

if [ ! -z "$OPTIONS" ];then
  if [[ "--include-oidc-credentials" =~ "$OPTIONS" ]]; then
    set_oidc_credentials
  fi

  if [[ "--include-tanzu-secrets" =~ "$OPTIONS" ]]; then
    set_tanzu_secrets
  fi

  if [[ "--include-route53-static-credentials" ]]; then
    set_route53_static_credentials
  fi
fi