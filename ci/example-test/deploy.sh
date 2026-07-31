#!/bin/bash
# Deploy the example test pipeline to Concourse
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="${FLY_TARGET:-example}"

echo "Deploying zap-scanner-test pipeline to ${TARGET}..."

fly -t "${TARGET}" set-pipeline \
  -p zap-scanner-test \
  -c "${SCRIPT_DIR}/pipeline.yml" \
  -l "${SCRIPT_DIR}/vars.yml" \
  --non-interactive

fly -t "${TARGET}" unpause-pipeline -p zap-scanner-test

echo ""
echo "Pipeline deployed! View at:"
echo "  https://((concourse_url))/teams/main/pipelines/zap-scanner-test"
echo ""
echo "Trigger the build:"
echo "  fly -t ${TARGET} trigger-job -j zap-scanner-test/build-zap-image -w"
