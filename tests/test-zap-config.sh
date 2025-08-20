#!/bin/bash
set -uo pipefail

echo "================================================"
echo "ZAP Runner Configuration Test Suite"
echo "================================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

# Test function
run_test() {
    local test_name="$1"
    local test_command="$2"
    
    echo -n "Testing: $test_name... "
    if eval "$test_command" > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗${NC}"
        ((TESTS_FAILED++))
        echo "  Command: $test_command"
    fi
}

echo ""
echo "1. Dockerfile Validation"
echo "------------------------"

# Check Dockerfile syntax
run_test "Dockerfile syntax" "docker build --dry-run -f ../Dockerfile .."

# Check for deprecated addOns job
run_test "No deprecated addOns in zap-af.yml" "! grep -q 'type: addOns' ../ci/tasks/zap-af.yml"

# Check for add-on installation in Dockerfile
run_test "Add-ons installed at build time" "grep -q 'addoninstall reportgenerator' ../Dockerfile"
run_test "OpenAPI addon installed" "grep -q 'addoninstall openapi' ../Dockerfile"

echo ""
echo "2. Configuration Files"
echo "----------------------"

# Check for required configuration files
run_test "Reporting config exists" "test -f ../ci/common/reporting.yml"
run_test "User agent file exists" "test -f ../ci/common/user-agent.txt"
run_test "Global exclusions file exists" "test -f ../ci/common/global-exclusions.txt"

# Validate YAML syntax
for yaml_file in ../ci/common/reporting.yml ../ci/scan-contexts/*/config.yml; do
    if [ -f "$yaml_file" ]; then
        run_test "Valid YAML: $yaml_file" "python3 -c 'import yaml; yaml.safe_load(open(\"$yaml_file\"))'"
    fi
done

echo ""
echo "3. Authentication Setup"
echo "-----------------------"

run_test "Auth acquisition task exists" "test -f ../ci/tasks/acquire-auth.yml"
run_test "Supports CF auth" "grep -q 'cf oauth-token' ../ci/tasks/acquire-auth.yml"
run_test "Supports OpsUAA auth" "grep -q 'uaac token owner' ../ci/tasks/acquire-auth.yml"
run_test "Supports header auth" "grep -q 'header)' ../ci/tasks/acquire-auth.yml"

echo ""
echo "4. ZAP AF Task Validation"
echo "-------------------------"

run_test "ZAP AF task exists" "test -f ../ci/tasks/zap-af.yml"
run_test "Uses replacer for auth" "grep -q 'type: replacer' ../ci/tasks/zap-af.yml"
run_test "Correct job order" "grep -A50 'type: options' ../ci/tasks/zap-af.yml | grep -q 'type: import'"
run_test "Multiple report formats" "grep -q 'traditional-html' ../ci/common/reporting.yml && grep -q 'sarif-json' ../ci/common/reporting.yml"

echo ""
echo "5. Best Practices Compliance"
echo "----------------------------"

run_test "Non-root user in container" "grep -q 'USER zap' ../Dockerfile"
run_test "Health check configured" "grep -q 'HEALTHCHECK' ../Dockerfile"
run_test "No hardcoded secrets" "! grep -E '(password|secret|token|key)=' ../ci/tasks/*.yml"
run_test "Volume for workspace" "grep -q 'VOLUME.*wrk' ../Dockerfile"

echo ""
echo "6. Build Test (Optional)"
echo "------------------------"
echo -e "${YELLOW}Note: Skipping actual Docker build to avoid long build times${NC}"
echo "To test the build, run:"
echo "  docker build -t zap-runner-test .."
echo ""

echo "================================================"
echo "Test Results Summary"
echo "================================================"
echo -e "Passed: ${GREEN}${TESTS_PASSED}${NC}"
echo -e "Failed: ${RED}${TESTS_FAILED}${NC}"

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "\n${GREEN}All tests passed! Your ZAP Runner configuration follows current best practices.${NC}"
    exit 0
else
    echo -e "\n${RED}Some tests failed. Please review the configuration.${NC}"
    exit 1
fi
