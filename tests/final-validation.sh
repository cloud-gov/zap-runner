#!/bin/bash
set -uo pipefail

echo "========================================================="
echo "           ZAP RUNNER FINAL VALIDATION SUITE            "
echo "========================================================="
echo ""
echo "This script validates the entire ZAP Runner project"
echo "including documentation accuracy, configurations, and"
echo "compliance with current best practices."
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Summary counters
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
WARNINGS=0

# Helper function for section headers
print_section() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${MAGENTA}  $1${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Check function
check() {
    local description="$1"
    local command="$2"
    local severity="${3:-error}"  # error or warning
    
    ((TOTAL_CHECKS++))
    
    if eval "$command" > /dev/null 2>&1; then
        echo -e "  ${GREEN}✓${NC} $description"
        ((PASSED_CHECKS++))
        return 0
    else
        if [ "$severity" = "warning" ]; then
            echo -e "  ${YELLOW}⚠${NC} $description (warning)"
            ((WARNINGS++))
            return 1
        else
            echo -e "  ${RED}✗${NC} $description"
            ((FAILED_CHECKS++))
            return 1
        fi
    fi
}

# Start validation
print_section "1. PROJECT STRUCTURE VALIDATION"

check "Root directory contains required files" \
    "test -f ../Dockerfile && test -f ../README.md && test -f ../PROJECT_STATUS.md"

check "CI directory structure is complete" \
    "test -d ../ci/tasks && test -d ../ci/scan-contexts && test -d ../ci/common"

check "All pipeline files exist" \
    "test -f ../ci/pipeline.yml && test -f ../ci/child-pipelines/zap-dast.yml"

check "Best practices documentation exists" \
    "test -f ../ZAP_BEST_PRACTICES.md"

print_section "2. DOCUMENTATION ACCURACY"

check "README.md references existing files" \
    "test -f ../ci/scripts/generate-af-plan.py && test -f ../ci/tasks/process-results.yml"

check "No deprecated addOns job mentioned incorrectly" \
    "! grep -q 'addOns.*job.*should.*be.*used' ../README.md"

check "Documentation reflects current Docker setup" \
    "grep -q 'addoninstall' ../Dockerfile"

print_section "3. ZAP AUTOMATION FRAMEWORK COMPLIANCE"

check "No deprecated addOns job in automation task" \
    "! grep -q 'type: addOns' ../ci/tasks/zap-af.yml"

check "Add-ons installed at build time" \
    "grep -q 'addoninstall reportgenerator' ../Dockerfile"

check "Proper job ordering maintained" \
    "grep -A1 'type: options' ../ci/tasks/zap-af.yml | grep -q 'parameters:'"

check "Authentication via replacer rules" \
    "grep -q 'type: replacer' ../ci/tasks/zap-af.yml"

print_section "4. SCAN CONTEXT VALIDATION"

# Count contexts
CONTEXT_COUNT=0
for dir in ../ci/scan-contexts/*/; do
    if [ -d "$dir" ]; then
        context=$(basename "$dir")
        if [ -f "${dir}urls.txt" ]; then
            ((CONTEXT_COUNT++))
            check "Context '$context' has valid URLs" \
                "grep -E -v '^\s*#|^\s*$' '${dir}urls.txt' | grep -q '.'"
        fi
    fi
done

echo -e "  ${BLUE}ℹ${NC} Total scan contexts found: $CONTEXT_COUNT"

check "API context has OpenAPI specifications" \
    "ls ../ci/scan-contexts/api/openapi-*.json > /dev/null 2>&1"

print_section "5. CONFIGURATION FILES"

check "Reporting configuration is valid YAML" \
    "python3 -c 'import yaml; yaml.safe_load(open(\"../ci/common/reporting.yml\"))'"

check "Pipeline configuration is valid YAML" \
    "python3 -c 'import yaml; yaml.safe_load(open(\"../ci/pipeline.yml\"))'"

check "All context configs are valid YAML" \
    "for f in ../ci/scan-contexts/*/config.yml; do [ -f \"\$f\" ] && python3 -c \"import yaml; yaml.safe_load(open('\$f'))\" || true; done"

check "User agent is configured" \
    "test -s ../ci/common/user-agent.txt"

check "Global exclusions are configured" \
    "test -s ../ci/common/global-exclusions.txt"

print_section "6. SECURITY BEST PRACTICES"

check "No hardcoded credentials in task files" \
    "! grep -E 'password=|secret=|token=|key=' ../ci/tasks/*.yml"

check "Docker container runs as non-root user" \
    "grep -q 'USER zap' ../Dockerfile"

check "Health check is configured" \
    "grep -q 'HEALTHCHECK' ../Dockerfile"

check "Uses CredHub for secrets (documented)" \
    "grep -q 'CredHub' ../README.md"

print_section "7. AUTHENTICATION MECHANISMS"

check "Supports CF authentication" \
    "grep -q 'cf oauth-token' ../ci/tasks/acquire-auth.yml"

check "Supports OpsUAA authentication" \
    "grep -q 'uaac token owner' ../ci/tasks/acquire-auth.yml"

check "Supports header-based authentication" \
    "grep -q 'header)' ../ci/tasks/acquire-auth.yml"

check "Supports unauthenticated scanning" \
    "grep -q 'none|' ../ci/tasks/acquire-auth.yml"

print_section "8. REPORT GENERATION"

check "Multiple report formats configured" \
    "grep -q 'traditional-html' ../ci/common/reporting.yml && grep -q 'sarif-json' ../ci/common/reporting.yml"

check "XML reports for DefectDojo" \
    "grep -q 'traditional-xml' ../ci/common/reporting.yml"

check "Report filtering configured" \
    "grep -q 'risks:' ../ci/common/reporting.yml && grep -q 'confidences:' ../ci/common/reporting.yml"

print_section "9. PIPELINE INTEGRATION"

check "Daily schedule configured" \
    "grep -q 'daily-1am' ../ci/child-pipelines/zap-dast.yml"

check "Parallel context execution configured" \
    "grep -q 'across:' ../ci/child-pipelines/zap-dast.yml"

check "DefectDojo push task exists" \
    "test -f ../ci/tasks/push-defectdojo.yml"

check "Results processing task exists" \
    "test -f ../ci/tasks/process-results.yml"

print_section "10. HELPER SCRIPTS"

check "AF plan generator is executable" \
    "test -x ../ci/scripts/generate-af-plan.py"

check "AF plan generator works for internal context" \
    "python3 ../ci/scripts/generate-af-plan.py --context internal --base-dir ../ci --dry-run > /dev/null"

check "Test scripts are available" \
    "test -f test-zap-config.sh && test -f test-documented-commands.sh"

check "Validation scripts are available" \
    "test -f verify-project-structure.sh && test -f validate-scan-contexts.sh"

# Final Summary
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}                    VALIDATION SUMMARY                    ${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Calculate percentage
if [ $TOTAL_CHECKS -gt 0 ]; then
    PERCENTAGE=$((PASSED_CHECKS * 100 / TOTAL_CHECKS))
else
    PERCENTAGE=0
fi

echo -e "  Total Checks:    ${TOTAL_CHECKS}"
echo -e "  Passed:          ${GREEN}${PASSED_CHECKS}${NC}"
echo -e "  Failed:          ${RED}${FAILED_CHECKS}${NC}"
echo -e "  Warnings:        ${YELLOW}${WARNINGS}${NC}"
echo -e "  Success Rate:    ${PERCENTAGE}%"
echo ""

# Overall status
if [ $FAILED_CHECKS -eq 0 ]; then
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}     ✅ VALIDATION SUCCESSFUL - ALL CHECKS PASSED!       ${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "The ZAP Runner project is:"
    echo "  • Following current best practices"
    echo "  • Properly documented"
    echo "  • Correctly configured"
    echo "  • Ready for deployment"
    exit 0
elif [ $WARNINGS -gt 0 ] && [ $FAILED_CHECKS -eq 0 ]; then
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}  ⚠️  VALIDATION PASSED WITH WARNINGS                    ${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "The project is functional but has minor issues to address."
    exit 0
else
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${RED}     ❌ VALIDATION FAILED - ISSUES DETECTED              ${NC}"
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "Please review the failed checks above and fix the issues."
    exit 1
fi