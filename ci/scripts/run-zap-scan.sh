#!/bin/bash
set -euo pipefail

echo "========================================"
echo "Starting ZAP scan for context: ${SCAN_CONTEXT}"
echo "========================================"

# Setup directories
WORK_DIR="/zap/wrk"
CONFIG_DIR="${WORK_DIR}/configs"
RESULTS_DIR="${WORK_DIR}/results"
REPORT_DIR="/tmp/zap-reports"

mkdir -p "${CONFIG_DIR}" "${RESULTS_DIR}" "${REPORT_DIR}"

# Copy context-specific configuration
cp -r "zap-runner/ci/scan-contexts/${SCAN_CONTEXT}"/* "${CONFIG_DIR}/"

# Load context configuration
source "${CONFIG_DIR}/config.yml"

# Start ZAP in daemon mode
echo "Starting ZAP daemon..."
/zap/zap.sh -daemon -host 0.0.0.0 -port 8080 \
  -config api.disablekey=true \
  -config spider.maxDepth="${SPIDER_MAX_DEPTH:-10}" \
  -config scanner.maxScanDurationInMins="${MAX_SCAN_DURATION:-60}" &

ZAP_PID=$!

# Function to check if ZAP is ready
wait_for_zap() {
  local max_attempts=60
  local attempt=0
  
  while ! curl -s http://localhost:8080/JSON/core/view/version/ > /dev/null; do
    if [ $attempt -ge $max_attempts ]; then
      echo "ERROR: ZAP failed to start after ${max_attempts} attempts"
      exit 1
    fi
    echo "Waiting for ZAP to start... (attempt $((attempt+1))/${max_attempts})"
    sleep 2
    ((attempt++))
  done
  
  echo "ZAP is ready!"
}

wait_for_zap

# Configure proxy if provided
if [[ -n "${PROXY_HOST:-}" ]] && [[ -n "${PROXY_PORT:-}" ]]; then
  echo "Configuring proxy: ${PROXY_HOST}:${PROXY_PORT}"
  curl -s "http://localhost:8080/JSON/network/action/setHttpProxy/?host=${PROXY_HOST}&port=${PROXY_PORT}"
  curl -s "http://localhost:8080/JSON/network/action/setHttpProxyEnabled/?enabled=true"
fi

# Create new context
echo "Creating context: ${SCAN_CONTEXT}"
curl -s "http://localhost:8080/JSON/context/action/newContext/?contextName=${SCAN_CONTEXT}"

# Get context ID
CONTEXT_ID=$(curl -s "http://localhost:8080/JSON/context/view/context/?contextName=${SCAN_CONTEXT}" | jq -r '.contextId')
echo "Context ID: ${CONTEXT_ID}"

# Load URLs from file
echo "Loading URLs..."
mapfile -t URLS < "${CONFIG_DIR}/urls.txt"

# Include URLs in context
for url in "${URLS[@]}"; do
  if [[ -n "$url" ]] && [[ ! "$url" =~ ^# ]]; then
    echo "Adding URL to context: ${url}"
    encoded_url=$(echo "$url.*" | jq -sRr @uri)
    curl -s "http://localhost:8080/JSON/context/action/includeInContext/?contextName=${SCAN_CONTEXT}&regex=${encoded_url}"
  fi
done

# Configure authentication based on AUTH_TYPE from config
configure_authentication() {
  case "${AUTH_TYPE:-none}" in
    "oauth2")
      if [[ -n "${AUTH_CLIENT_ID:-}" ]] && [[ -n "${AUTH_CLIENT_SECRET:-}" ]] && [[ -n "${AUTH_TOKEN_URI:-}" ]]; then
        echo "Configuring OAuth2 authentication..."
        
        # Load OAuth2 script
        if [[ -f "zap-runner/ci/scripts/auth-scripts/uaa-oauth2.js" ]]; then
          SCRIPT_CONTENT=$(cat "zap-runner/ci/scripts/auth-scripts/uaa-oauth2.js")
          curl -s -X POST "http://localhost:8080/JSON/script/action/load/" \
            --data-urlencode "scriptName=oauth2-${SCAN_CONTEXT}" \
            --data-urlencode "scriptType=authentication" \
            --data-urlencode "scriptEngine=ECMAScript" \
            --data-urlencode "scriptDescription=OAuth2 authentication for ${SCAN_CONTEXT}" \
            --data-urlencode "scriptData=${SCRIPT_CONTENT}"
        fi
        
        # Set authentication method
        curl -s "http://localhost:8080/JSON/authentication/action/setAuthenticationMethod/?contextId=${CONTEXT_ID}&authMethodName=scriptBasedAuthentication&authMethodConfigParams=scriptName%3Doauth2-${SCAN_CONTEXT}%26clientId%3D${AUTH_CLIENT_ID}%26clientSecret%3D${AUTH_CLIENT_SECRET}%26tokenUrl%3D${AUTH_TOKEN_URI}"
      fi
      ;;
      
    "form")
      if [[ -n "${AUTH_USERNAME:-}" ]] && [[ -n "${AUTH_PASSWORD:-}" ]]; then
        echo "Configuring form-based authentication..."
        
        # Set form-based authentication
        LOGIN_URL="${AUTH_LOGIN_URL:-https://auth.cloud.gov/login}"
        curl -s "http://localhost:8080/JSON/authentication/action/setAuthenticationMethod/?contextId=${CONTEXT_ID}&authMethodName=formBasedAuthentication&authMethodConfigParams=loginUrl%3D${LOGIN_URL}%26loginRequestData%3Dusername%3D%7B%25username%25%7D%26password%3D%7B%25password%25%7D"
        
        # Create user and set credentials
        curl -s "http://localhost:8080/JSON/users/action/newUser/?contextId=${CONTEXT_ID}&name=${AUTH_USERNAME}"
        USER_ID=$(curl -s "http://localhost:8080/JSON/users/view/usersList/?contextId=${CONTEXT_ID}" | jq -r '.usersList[0].id')
        
        curl -s "http://localhost:8080/JSON/users/action/setAuthenticationCredentials/?contextId=${CONTEXT_ID}&userId=${USER_ID}&authCredentialsConfigParams=username%3D${AUTH_USERNAME}%26password%3D${AUTH_PASSWORD}"
      fi
      ;;
      
    "header")
      if [[ -n "${AUTH_TOKEN:-}" ]];
            then
        echo "Configuring header-based authentication..."
        
        # Add authentication header
        curl -s "http://localhost:8080/JSON/replacer/action/addRule/?description=AuthHeader-${SCAN_CONTEXT}&enabled=true&matchType=REQ_HEADER&matchRegex=false&matchString=Authorization&replacement=Bearer%20${AUTH_TOKEN}"
      fi
      ;;
      
    "api-key")
      if [[ -n "${AUTH_API_KEY:-}" ]]; then
        echo "Configuring API key authentication..."
        
        # Add API key header
        API_KEY_HEADER="${AUTH_API_KEY_HEADER:-X-API-Key}"
        curl -s "http://localhost:8080/JSON/replacer/action/addRule/?description=APIKey-${SCAN_CONTEXT}&enabled=true&matchType=REQ_HEADER&matchRegex=false&matchString=${API_KEY_HEADER}&replacement=${AUTH_API_KEY}"
      fi
      ;;
      
    "none")
      echo "No authentication configured"
      ;;
      
    *)
      echo "Unknown authentication type: ${AUTH_TYPE}"
      ;;
  esac
}

# Configure authentication
configure_authentication

# Function to run spider
run_spider() {
  local url=$1
  echo "Starting spider for: ${url}"
  
  SPIDER_SCAN_ID=$(curl -s "http://localhost:8080/JSON/spider/action/scan/?contextName=${SCAN_CONTEXT}&url=${url}&recurse=true&subtreeOnly=true&maxDepth=${SPIDER_MAX_DEPTH:-10}" | jq -r '.scan')
  
  # Wait for spider to complete
  while true; do
    STATUS=$(curl -s "http://localhost:8080/JSON/spider/view/status/?scanId=${SPIDER_SCAN_ID}" | jq -r '.status')
    if [[ "${STATUS}" == "100" ]]; then
      echo "Spider completed for ${url}"
      break
    fi
    echo "Spider progress: ${STATUS}%"
    sleep 5
  done
}

# Function to run active scan
run_active_scan() {
  local url=$1
  echo "Starting active scan for: ${url}"
  
  ASCAN_ID=$(curl -s "http://localhost:8080/JSON/ascan/action/scan/?url=${url}&contextId=${CONTEXT_ID}&recurse=true&scanPolicyName=Default%20Policy" | jq -r '.scan')
  
  # Wait for active scan to complete
  while true; do
    STATUS=$(curl -s "http://localhost:8080/JSON/ascan/view/status/?scanId=${ASCAN_ID}" | jq -r '.status')
    if [[ "${STATUS}" == "100" ]]; then
      echo "Active scan completed for ${url}"
      break
    fi
    echo "Active scan progress: ${STATUS}%"
    sleep 10
  done
}

# Function to run API scan
run_api_scan() {
  local url=$1
  local openapi_file="${CONFIG_DIR}/openapi.json"
  
  if [[ -f "${openapi_file}" ]]; then
    echo "Running API scan with OpenAPI definition..."
    
    # Import OpenAPI definition
    curl -s -X POST "http://localhost:8080/JSON/openapi/action/importFile/" \
      --form "file=@${openapi_file}" \
      --form "contextId=${CONTEXT_ID}" \
      --form "target=${url}"
    
    # Run active scan on imported endpoints
    run_active_scan "${url}"
  else
    echo "No OpenAPI definition found, running standard scan..."
    run_spider "${url}"
    run_active_scan "${url}"
  fi
}

# Run scans based on SCAN_TYPE
case "${SCAN_TYPE:-full}" in
  "baseline")
    echo "Running baseline scan..."
    for url in "${URLS[@]}"; do
      if [[ -n "$url" ]] && [[ ! "$url" =~ ^# ]]; then
        run_spider "${url}"
      fi
    done
    ;;
    
  "api")
    echo "Running API scan..."
    for url in "${URLS[@]}"; do
      if [[ -n "$url" ]] && [[ ! "$url" =~ ^# ]]; then
        run_api_scan "${url}"
      fi
    done
    ;;
    
  "full"|*)
    echo "Running full scan..."
    for url in "${URLS[@]}"; do
      if [[ -n "$url" ]] && [[ ! "$url" =~ ^# ]]; then
        run_spider "${url}"
        run_active_scan "${url}"
      fi
    done
    ;;
esac

# Wait for passive scanning to complete
echo "Waiting for passive scanning to complete..."
while true; do
  RECORDS=$(curl -s "http://localhost:8080/JSON/pscan/view/recordsToScan/" | jq -r '.recordsToScan')
  if [[ "${RECORDS}" == "0" ]]; then
    echo "Passive scanning completed"
    break
  fi
  echo "Passive scan records remaining: ${RECORDS}"
  sleep 5
done

# Generate reports
echo "Generating reports..."
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
REPORT_PREFIX="${SCAN_CONTEXT}-${TIMESTAMP}"

# Generate multiple report formats
generate_reports() {
  # HTML report
  curl -s "http://localhost:8080/OTHER/core/other/htmlreport/" > "${REPORT_DIR}/${REPORT_PREFIX}.html"
  
  # JSON report
  curl -s "http://localhost:8080/OTHER/core/other/jsonreport/" | jq '.' > "${REPORT_DIR}/${REPORT_PREFIX}.json"
  
  # XML report
  curl -s "http://localhost:8080/OTHER/core/other/xmlreport/" > "${REPORT_DIR}/${REPORT_PREFIX}.xml"
  
  # SARIF report for GitHub integration
  curl -s "http://localhost:8080/JSON/reports/action/generate/?title=${SCAN_CONTEXT}&template=sarif-json&reportFileName=${REPORT_PREFIX}.sarif.json&reportDir=${REPORT_DIR}/"
  
  # Generate summary
  generate_summary
}

# Generate summary report
generate_summary() {
  local summary_file="${REPORT_DIR}/${REPORT_PREFIX}-summary.json"
  
  # Get alert summary
  ALERTS=$(curl -s "http://localhost:8080/JSON/core/view/alertsSummary/")
  
  # Get scan statistics
  URLS_SCANNED=$(curl -s "http://localhost:8080/JSON/core/view/urls/" | jq '.urls | length')
  
  # Create summary JSON
  cat > "${summary_file}" <<EOF
{
  "scan_context": "${SCAN_CONTEXT}",
  "timestamp": "${TIMESTAMP}",
  "urls_scanned": ${URLS_SCANNED},
  "alert_summary": ${ALERTS},
  "scan_configuration": {
    "auth_type": "${AUTH_TYPE:-none}",
    "scan_type": "${SCAN_TYPE:-full}",
    "spider_max_depth": ${SPIDER_MAX_DEPTH:-10},
    "max_scan_duration": ${MAX_SCAN_DURATION:-60}
  }
}
EOF
}

generate_reports

# Check alert threshold
check_alerts() {
  local threshold="${ALERT_THRESHOLD:-MEDIUM}"
  local exit_code=0
  
  case "${threshold}" in
    "HIGH")
      HIGH_ALERTS=$(curl -s "http://localhost:8080/JSON/core/view/numberOfAlerts/?riskId=3" | jq -r '.numberOfAlerts')
      if [[ "${HIGH_ALERTS}" -gt 0 ]]; then
        echo "ERROR: Found ${HIGH_ALERTS} HIGH risk alerts"
        exit_code=1
      fi
      ;;
      
    "MEDIUM")
      MEDIUM_PLUS=$(curl -s "http://localhost:8080/JSON/core/view/numberOfAlerts/?riskId=2" | jq -r '.numberOfAlerts')
      HIGH_ALERTS=$(curl -s "http://localhost:8080/JSON/core/view/numberOfAlerts/?riskId=3" | jq -r '.numberOfAlerts')
      TOTAL=$((MEDIUM_PLUS + HIGH_ALERTS))
      if [[ "${TOTAL}" -gt 0 ]]; then
        echo "ERROR: Found ${TOTAL} MEDIUM+ risk alerts"
        exit_code=1
      fi
      ;;
  esac
  
  return ${exit_code}
}

# Package reports
echo "Packaging reports..."
cd "${REPORT_DIR}"
tar -czf "/tmp/zap-reports/${REPORT_PREFIX}.tar.gz"*

# Copy to output
cp -r /tmp/zap-reports/* zap-reports/

# Clean up
kill ${ZAP_PID} || true

echo "========================================"
echo "Scan completed for context: ${SCAN_CONTEXT}"
echo "Reports available in: zap-reports/${REPORT_PREFIX}.tar.gz"
echo "========================================"

# Check alerts and exit with appropriate code
if ! check_alerts; then
  echo "Scan failed due to alerts exceeding threshold"
  exit 1
fi

echo "Scan passed all checks"
exit 0
