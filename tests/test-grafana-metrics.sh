#!/bin/bash
# Test Grafana metrics and dashboard configuration

set -euo pipefail

echo "========================================"
echo " Testing Grafana & Metrics Configuration"
echo "========================================"
echo ""

PASS=0
FAIL=0

# Test function
test_item() {
    local test_name="$1"
    local test_cmd="$2"
    
    echo -n "Testing: $test_name... "
    if eval "$test_cmd" 2>/dev/null; then
        echo "✅ PASS"
        ((PASS++))
    else
        echo "❌ FAIL"
        ((FAIL++))
    fi
}

# Test dashboard JSON validity
test_item "Grafana dashboard JSON valid" \
    "jq '.' ../ci/grafana/dashboard.json > /dev/null"

# Test dashboard has required panels
test_item "Dashboard has vulnerability panels" \
    "[[ \$(jq '.panels | length' ../ci/grafana/dashboard.json) -ge 10 ]]"

# Test metrics export task exists
test_item "Metrics export task exists" \
    "[[ -f ../ci/tasks/export-metrics.yml ]]"

# Test alerts task exists
test_item "Enhanced alerts task exists" \
    "[[ -f ../ci/tasks/send-alerts.yml ]]"

# Test Grafana setup documentation
test_item "Grafana setup docs exist" \
    "[[ -f ../docs/GRAFANA_SETUP.md ]]"

# Test metrics collector script
test_item "Metrics collector script exists" \
    "[[ -f ../ci/scripts/collect-metrics.py ]]"

# Test metrics collector Python syntax
test_item "Metrics collector Python valid" \
    "python3 -m py_compile ../ci/scripts/collect-metrics.py"

# Test dashboard has Prometheus queries
test_item "Dashboard has Prometheus queries" \
    "[[ \$(jq '[.panels[].targets[].expr] | length' ../ci/grafana/dashboard.json 2>/dev/null || echo 0) -gt 0 ]]"

# Test dashboard has proper datasource
test_item "Dashboard uses Prometheus datasource" \
    "[[ \$(jq -r '.panels[0].datasource' ../ci/grafana/dashboard.json) == 'Prometheus' ]]"

# Test dashboard has time range settings
test_item "Dashboard has time range configured" \
    "[[ \$(jq -r '.time.from' ../ci/grafana/dashboard.json) == 'now-24h' ]]"

# Test dashboard has refresh interval
test_item "Dashboard has refresh interval" \
    "[[ \$(jq -r '.refresh' ../ci/grafana/dashboard.json) == '30s' ]]"

# Test alert thresholds in pipeline
test_item "Pipeline has alert thresholds" \
    "grep -q 'HIGH_THRESHOLD' ../ci/child-pipelines/zap-dast.yml"

# Test Slack webhook configuration
test_item "Pipeline has Slack webhook config" \
    "grep -q 'SLACK_WEBHOOK_URL' ../ci/child-pipelines/zap-dast.yml"

# Test metrics export in pipeline
test_item "Pipeline includes metrics export" \
    "grep -q 'export-metrics' ../ci/child-pipelines/zap-dast.yml"

# Test enhanced alerts in pipeline
test_item "Pipeline includes enhanced alerts" \
    "grep -q 'send-alerts' ../ci/child-pipelines/zap-dast.yml"

# Test dashboard variable configuration
test_item "Dashboard has context variable" \
    "[[ \$(jq '.templating.list | length' ../ci/grafana/dashboard.json) -gt 0 ]]"

# Test dashboard tags
test_item "Dashboard has proper tags" \
    "[[ \$(jq '.tags | length' ../ci/grafana/dashboard.json) -ge 3 ]]"

# Test alert task Python syntax
if [ -f ../ci/tasks/send-alerts.yml ]; then
    # Extract Python code from YAML and test syntax
    echo -n "Testing: Alert task Python code valid... "
    sed -n '/python3 - <<.*PYTHON/,/PYTHON$/p' ../ci/tasks/send-alerts.yml | \
        sed '1d;$d' > /tmp/test_alerts.py 2>/dev/null
    if python3 -m py_compile /tmp/test_alerts.py 2>/dev/null; then
        echo "✅ PASS"
        ((PASS++))
    else
        echo "❌ FAIL"
        ((FAIL++))
    fi
    rm -f /tmp/test_alerts.py
fi

# Test Grafana setup documentation content
test_item "Grafana docs have cloud.gov instructions" \
    "grep -q 'cloud.gov' ../docs/GRAFANA_SETUP.md"

test_item "Grafana docs have Prometheus config" \
    "grep -q 'prometheus' ../docs/GRAFANA_SETUP.md"

test_item "Grafana docs have dashboard import steps" \
    "grep -q 'Import Dashboard' ../docs/GRAFANA_SETUP.md"

# Summary
echo ""
echo "========================================"
echo " Grafana & Metrics Test Results"
echo "========================================"
echo "Passed: $PASS"
echo "Failed: $FAIL"
echo ""

if [ "$FAIL" -eq 0 ]; then
    echo "✅ All Grafana & metrics tests passed!"
    exit 0
else
    echo "❌ Some tests failed. Please review."
    exit 1
fi