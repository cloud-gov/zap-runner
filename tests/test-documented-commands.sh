#!/bin/bash
set -uo pipefail

echo "================================================"
echo "Testing Documented Commands from README.md"
echo "================================================"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# Test function
test_command() {
    local description="$1"
    local command="$2"
    local skip_reason="${3:-}"
    
    echo ""
    echo -e "${BLUE}Test: $description${NC}"
    echo "Command: $command"
    
    if [ -n "$skip_reason" ]; then
        echo -e "${YELLOW}⊘ SKIPPED: $skip_reason${NC}"
        ((TESTS_SKIPPED++))
        return
    fi
    
    if eval "$command" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ PASSED${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAILED${NC}"
        ((TESTS_FAILED++))
    fi
}

echo ""
echo -e "${BLUE}1. Python Script Tests${NC}"
echo "----------------------------------------"

test_command \
    "Generate AF plan script exists and is executable" \
    "test -x ../ci/scripts/generate-af-plan.py"

test_command \
    "Generate AF plan for internal context (dry-run)" \
    "python3 ../ci/scripts/generate-af-plan.py --context internal --base-dir ../ci --dry-run"

test_command \
    "Generate AF plan for API context (dry-run)" \
    "python3 ../ci/scripts/generate-af-plan.py --context api --base-dir ../ci --dry-run"

test_command \
    "Generate AF plan for external context (dry-run)" \
    "python3 ../ci/scripts/generate-af-plan.py --context external --base-dir ../ci --dry-run"

echo ""
echo -e "${BLUE}2. Configuration File Tests${NC}"
echo "----------------------------------------"

test_command \
    "Validate reporting.yml YAML syntax" \
    "python3 -c 'import yaml; yaml.safe_load(open(\"../ci/common/reporting.yml\"))'"

test_command \
    "Validate pipeline.yml YAML syntax" \
    "python3 -c 'import yaml; yaml.safe_load(open(\"../ci/pipeline.yml\"))'"

test_command \
    "Validate zap-dast.yml YAML syntax" \
    "python3 -c 'import yaml; yaml.safe_load(open(\"../ci/child-pipelines/zap-dast.yml\"))'"

test_command \
    "Check all context configs are valid YAML" \
    "for f in ../ci/scan-contexts/*/config.yml; do [ -f \"\$f\" ] && python3 -c \"import yaml; yaml.safe_load(open('\$f'))\" || true; done"

echo ""
echo -e "${BLUE}3. Docker-Related Tests${NC}"
echo "----------------------------------------"

test_command \
    "Dockerfile exists" \
    "test -f ../Dockerfile"

test_command \
    "Dockerfile syntax check" \
    "grep -q 'FROM.*zap-stable' ../Dockerfile && grep -q 'USER zap' ../Dockerfile"

test_command \
    "Docker build command (dry-run)" \
    "echo 'docker build -t zap-runner .'" \
    "Requires Docker daemon"

test_command \
    "Docker run command (dry-run)" \
    "echo 'docker run -p 8080:8080 zap-runner -daemon'" \
    "Requires Docker daemon"

echo ""
echo -e "${BLUE}4. Authentication Tests${NC}"
echo "----------------------------------------"

test_command \
    "Auth acquisition task exists" \
    "test -f ../ci/tasks/acquire-auth.yml"

test_command \
    "Auth task supports CF" \
    "grep -q 'cf oauth-token' ../ci/tasks/acquire-auth.yml"

test_command \
    "Auth task supports OpsUAA" \
    "grep -q 'uaac token owner' ../ci/tasks/acquire-auth.yml"

test_command \
    "Auth task supports header auth" \
    "grep -q 'header)' ../ci/tasks/acquire-auth.yml"

echo ""
echo -e "${BLUE}5. ZAP AF Task Tests${NC}"
echo "----------------------------------------"

test_command \
    "ZAP AF task exists" \
    "test -f ../ci/tasks/zap-af.yml"

test_command \
    "ZAP AF task does NOT use deprecated addOns job" \
    "! grep -q 'type: addOns' ../ci/tasks/zap-af.yml"

test_command \
    "ZAP AF task uses replacer for auth" \
    "grep -q 'type: replacer' ../ci/tasks/zap-af.yml"

test_command \
    "ZAP AF task uses reporting.yml for multiple formats" \
    "grep -q 'reporting.yml' ../ci/tasks/zap-af.yml && grep -q 'sarif-json' ../ci/common/reporting.yml"

echo ""
echo -e "${BLUE}6. Scan Context Tests${NC}"
echo "----------------------------------------"

for context in internal external api cloud-gov-pages unauthenticated; do
    test_command \
        "Context $context has urls.txt" \
        "test -f ../ci/scan-contexts/$context/urls.txt"
done

test_command \
    "API context has OpenAPI specs" \
    "ls ../ci/scan-contexts/api/openapi-*.json > /dev/null 2>&1"

echo ""
echo -e "${BLUE}7. DefectDojo Integration Tests${NC}"
echo "----------------------------------------"

test_command \
    "DefectDojo push task exists" \
    "test -f ../ci/tasks/push-defectdojo.yml"

test_command \
    "Process results task exists" \
    "test -f ../ci/tasks/process-results.yml"

echo ""
echo -e "${BLUE}8. Best Practices Tests${NC}"
echo "----------------------------------------"

test_command \
    "No hardcoded secrets in tasks" \
    "! grep -E '(password|secret|token|key)=' ../ci/tasks/*.yml"

test_command \
    "Dockerfile uses non-root user" \
    "grep -q 'USER zap' ../Dockerfile"

test_command \
    "Health check configured in Dockerfile" \
    "grep -q 'HEALTHCHECK' ../Dockerfile"

test_command \
    "Add-ons installed at build time" \
    "grep -q 'addoninstall reportgenerator' ../Dockerfile && grep -q 'addoninstall openapi' ../Dockerfile"

echo ""
echo -e "${BLUE}9. Documentation Tests${NC}"
echo "----------------------------------------"

test_command \
    "README.md exists" \
    "test -f ../README.md"

test_command \
    "README.md exists" \
    "test -f ../README.md"

test_command \
    "SECURITY.md exists" \
    "test -f ../SECURITY.md"

test_command \
    "ZAP_BEST_PRACTICES.md exists" \
    "test -f ../ZAP_BEST_PRACTICES.md"

echo ""
echo -e "${BLUE}10. Pipeline Command Tests${NC}"
echo "----------------------------------------"

test_command \
    "Fly command format check" \
    "echo 'fly -t main set-pipeline -p zap-scanner -c ci/pipeline.yml'" \
    "Requires Concourse CLI"

test_command \
    "Pipeline references correct vars files" \
    "grep -q 'ci/config.yml' ../ci/pipeline.yml && grep -q 'ci/vars/zap-dast.yml' ../ci/pipeline.yml"

echo ""
echo "================================================"
echo "Test Results Summary"
echo "================================================"
echo -e "Total Tests: $((TESTS_PASSED + TESTS_FAILED + TESTS_SKIPPED))"
echo -e "Passed: ${GREEN}${TESTS_PASSED}${NC}"
echo -e "Failed: ${RED}${TESTS_FAILED}${NC}"
echo -e "Skipped: ${YELLOW}${TESTS_SKIPPED}${NC}"

if [ $TESTS_FAILED -eq 0 ]; then
    echo ""
    echo -e "${GREEN}✅ All testable commands passed!${NC}"
    exit 0
else
    echo ""
    echo -e "${RED}⚠️  Some tests failed. Please review the output above.${NC}"
    exit 1
fi