#!/usr/bin/env bash

# Establish Personal Access Token
# @see https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens
# It's highly recommended to create a fine-grained personal access token

# Name of the secret to create
SECRET_NAME="PA_TOKEN"

if [ $# -ne 3 ]; then
    echo "Usage: ./set-personal-access-token.sh {owner} {personal-access-token-value} {target-cloud}"
    echo "  parameters: {target-cloud} is one of [ aws, azure, google ], {owner} is the repository owner or an organization name, and {personal-access-token-value} is a fine-grained personal access token for Github"
    exit 1
fi

# Change 'username/repo' to your GitHub repository
OWNER="${1:-clicktuck}"
# PAT value passed as an argument
PAT_VALUE="$2"
TARGET_CLOUD="$3"


# Check if GitHub CLI is installed
if ! command -v gh &> /dev/null
then
    echo "GitHub CLI could not be found, please install it."
    exit 1
fi

# Check if user is logged in to GitHub CLI
if ! gh auth status &> /dev/null
then
    echo "You are not logged in to GitHub CLI. Please log in using 'gh auth login'."
    exit 1
fi

case $TARGET_CLOUD in
    "aws"|"azure"|"google")
        echo "Valid cloud provider: $TARGET_CLOUD"
        # Create or update a repository secret
        gh secret set $SECRET_NAME -b"$PAT_VALUE" --repo $OWNER/$TARGET_CLOUD-actions
        ;;
    *)
        echo "Invalid cloud provider: $TARGET_CLOUD. Please specify 'aws', 'azure', or 'google'."
        exit 1
        ;;
esac

if [ $? -eq 0 ]; then
    echo "Secret '$SECRET_NAME' successfully set in repository '$OWNER/$TARGET_CLOUD-actions'."
else
    echo "Failed to set the secret. Please check your inputs and permissions."
    exit 1
fi