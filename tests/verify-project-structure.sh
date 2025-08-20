#!/bin/bash
set -euo pipefail

echo "================================================"
echo "ZAP Runner Project Structure Verification"
echo "================================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
TOTAL=0
FOUND=0
MISSING=0
ISSUES=""

# Check function
check_file() {
    local file="$1"
    local description="$2"
    ((TOTAL++))
    
    if [ -f "$file" ]; then
        echo -e "${GREEN}✓${NC} $description: $file"
        ((FOUND++))
    else
        echo -e "${RED}✗${NC} $description: $file"
        ((MISSING++))
        ISSUES="${ISSUES}Missing file: $file\n"
    fi
}

check_dir() {
    local dir="$1"
    local description="$2"
    ((TOTAL++))
    
    if [ -d "$dir" ]; then
        echo -e "${GREEN}✓${NC} $description: $dir"
        ((FOUND++))
    else
        echo -e "${RED}✗${NC} $description: $dir"
        ((MISSING++))
        ISSUES="${ISSUES}Missing directory: $dir\n"
    fi
}

echo ""
echo -e "${BLUE}1. Core Files${NC}"
echo "------------------------"
check_file "../Dockerfile" "Dockerfile"
check_file "../README.md" "README documentation"
check_file "../PROJECT_STATUS.md" "Project status"
check_file "../project_plan.md" "Project plan"
check_file "../ZAP_BEST_PRACTICES.md" "Best practices doc"
check_file "test-zap-config.sh" "Test script"

echo ""
echo -e "${BLUE}2. CI Directory Structure${NC}"
echo "------------------------"
check_dir "../ci" "CI root directory"
check_dir "../ci/common" "Common configs"
check_dir "../ci/scan-contexts" "Scan contexts"
check_dir "../ci/tasks" "Concourse tasks"
check_dir "../ci/child-pipelines" "Child pipelines"
check_dir "../ci/vars" "Pipeline variables"

echo ""
echo -e "${BLUE}3. Common Configuration Files${NC}"
echo "------------------------"
check_file "../ci/common/user-agent.txt" "User agent config"
check_file "../ci/common/global-exclusions.txt" "Global exclusions"
check_file "../ci/common/reporting.yml" "Reporting config"

echo ""
echo -e "${BLUE}4. Pipeline Files${NC}"
echo "------------------------"
check_file "../ci/pipeline.yml" "Main pipeline"
check_file "../ci/config.yml" "Pipeline config"
check_file "../ci/child-pipelines/zap-dast.yml" "DAST pipeline"
check_file "../ci/vars/zap-dast.yml" "DAST variables"

echo ""
echo -e "${BLUE}5. Task Files${NC}"
echo "------------------------"
check_file "../ci/tasks/acquire-auth.yml" "Auth acquisition task"
check_file "../ci/tasks/zap-af.yml" "ZAP automation framework task"
check_file "../ci/tasks/push-defectdojo.yml" "DefectDojo push task"
check_file "../ci/tasks/process-results.yml" "Results processing task"

echo ""
echo -e "${BLUE}6. Scan Contexts${NC}"
echo "------------------------"
for context in internal external cloud-gov-pages api unauthenticated example-team; do
    check_dir "../ci/scan-contexts/$context" "$context context"
    check_file "../ci/scan-contexts/$context/urls.txt" "$context URLs"
    # config.yml is optional, so we'll just note if it exists
    if [ -f "../ci/scan-contexts/$context/config.yml" ]; then
        echo -e "${GREEN}✓${NC} $context config: ../ci/scan-contexts/$context/config.yml"
    else
        echo -e "${YELLOW}ℹ${NC} $context config: ../ci/scan-contexts/$context/config.yml (optional, not present)"
    fi
done

echo ""
echo -e "${BLUE}7. API Context OpenAPI Specs${NC}"
echo "------------------------"
# Check for OpenAPI specs in API context
if [ -d "../ci/scan-contexts/api" ]; then
    openapi_files=$(find ../ci/scan-contexts/api -name "openapi-*.json" 2>/dev/null | head -5)
    if [ -n "$openapi_files" ]; then
        for spec in $openapi_files; do
            echo -e "${GREEN}✓${NC} OpenAPI spec: $spec"
        done
    else
        echo -e "${YELLOW}ℹ${NC} No OpenAPI specs found in api context"
    fi
fi

echo ""
echo -e "${BLUE}8. Scripts Directory${NC}"
echo "------------------------"
check_dir "../ci/scripts" "Scripts directory"
if [ -d "../ci/scripts" ]; then
    for script in ../ci/scripts/*.py ../ci/scripts/*.sh; do
        if [ -f "$script" ]; then
            echo -e "${GREEN}✓${NC} Script: $script"
        fi
    done
fi

echo ""
echo -e "${BLUE}9. Documentation References Check${NC}"
echo "------------------------"
# Check if generate-af-plan.py exists as mentioned in README.md
if [ -f "../ci/scripts/generate-af-plan.py" ]; then
    echo -e "${GREEN}✓${NC} generate-af-plan.py exists"
else
    echo -e "${YELLOW}ℹ${NC} generate-af-plan.py not found (mentioned in README.md)"
fi

echo ""
echo "================================================"
echo "Verification Summary"
echo "================================================"
echo -e "Total checks: ${TOTAL}"
echo -e "Found: ${GREEN}${FOUND}${NC}"
echo -e "Missing: ${RED}${MISSING}${NC}"

if [ $MISSING -gt 0 ]; then
    echo ""
    echo -e "${RED}Issues Found:${NC}"
    echo -e "$ISSUES"
fi

echo ""
echo -e "${BLUE}Additional Information:${NC}"
echo "------------------------"
# Count scan contexts
num_contexts=$(find ../ci/scan-contexts -maxdepth 1 -type d | grep -v "^../ci/scan-contexts$" | wc -l)
echo "Number of scan contexts: $num_contexts"

# Check for any .yml files in tasks
num_tasks=$(find ../ci/tasks -name "*.yml" 2>/dev/null | wc -l)
echo "Number of task files: $num_tasks"

# Check for pipeline files
num_pipelines=$(find ../ci -name "pipeline.yml" -o -name "*-pipeline.yml" 2>/dev/null | wc -l)
echo "Number of pipeline files: $num_pipelines"

if [ $MISSING -eq 0 ]; then
    echo ""
    echo -e "${GREEN}✅ All documented files and directories are present!${NC}"
    exit 0
else
    echo ""
    echo -e "${YELLOW}⚠️  Some files/directories are missing. Review the issues above.${NC}"
    exit 1
fi