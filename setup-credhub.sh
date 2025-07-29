#!/bin/bash
set -euo pipefail

echo "Setting up CredHub credentials for ZAP Scanner"

# Check if logged into CredHub
if ! credhub find -n test >/dev/null 2>&1; then
    echo "Please login to CredHub first:"
    echo "credhub login -s https://credhub.fr.cloud.gov:8844"
    exit 1
fi

# Base path for credentials
BASE_PATH="/concourse/main/zap-scanner"

# Function to set credential
set_cred() {
    local name=$1
    local type=$2
    local value=$3
    
    echo "Setting: ${BASE_PATH}/${name}"
    credhub set -n "${BASE_PATH}/${name}" -t "${type}" -v "${value}"
}

# Function to set password credential
set_password() {
    local name=$1
    echo "Setting password: ${BASE_PATH}/${name}"
    credhub set -n "${BASE_PATH}/${name}" -t password -w
}

echo "=== Setting up Internal Context (UAA OAuth2) ==="
read -pr "Internal UAA Client ID: " internal_client_id
set_cred "internal-client-id" "value" "${internal_client_id}"

read -spr "Internal UAA Client Secret: " internal_client_secret
echo
set_cred "internal-client-secret" "value" "${internal_client_secret}"

set_cred "internal-token-uri" "value" "https://uaa.fr.cloud.gov/oauth/token"

read -pr "Internal Proxy Host (press enter to skip): " internal_proxy_host
if [ -n "${internal_proxy_host}" ]; then
    set_cred "internal-proxy-host" "value" "${internal_proxy_host}"
    read -pr "Internal Proxy Port: " internal_proxy_port
    set_cred "internal-proxy-port" "value" "${internal_proxy_port}"
fi

echo -e "\n=== Setting up API Context ==="
read -pr "API Bearer Token: " api_token
set_cred "api-token" "value" "${api_token}"

echo -e "\n=== Setting up Cloud.gov Pages Context ==="
read -pr "Pages Username: " pages_username
set_cred "cloud-gov-pages-username" "value" "${pages_username}"

echo "Pages Password (will be hidden):"
set_password "cloud-gov-pages-password"

echo -e "\n=== Setting up Slack Notifications ==="
read -pr "Slack Webhook URL: " slack_webhook
set_cred "slack-webhook-url" "value" "${slack_webhook}"

echo -e "\n=== Setting up S3 Buckets ==="
read -pr "Results Bucket Name: " results_bucket
set_cred "results-bucket" "value" "${results_bucket}"

read -p "Dashboard Bucket Name: " dashboard_bucket
set_cred "dashboard-bucket" "value" "${dashboard_bucket}"

echo -e "\n✅ CredHub setup complete!"
echo -e "\nTo verify credentials:"
echo "credhub find -p ${BASE_PATH}"