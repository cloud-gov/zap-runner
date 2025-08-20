#!/bin/bash
set -euo pipefail

echo "================================================"
echo "Validating All Scan Contexts"
echo "================================================"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Counters
CONTEXTS_VALID=0
CONTEXTS_INVALID=0
TOTAL_URLS=0
ISSUES=""

# Validate each context
for context_dir in ../ci/scan-contexts/*/; do
    if [ ! -d "$context_dir" ]; then
        continue
    fi
    
    context_name=$(basename "$context_dir")
    
    # Skip test-template.yml
    if [ "$context_name" = "test-template.yml" ]; then
        continue
    fi
    
    echo ""
    echo -e "${BLUE}Checking context: $context_name${NC}"
    echo "----------------------------------------"
    
    CONTEXT_VALID=true
    
    # Check for required urls.txt
    if [ -f "${context_dir}urls.txt" ]; then
        url_count=$(grep -E -v '^\s*#|^\s*$' "${context_dir}urls.txt" 2>/dev/null | wc -l)
        if [ "$url_count" -gt 0 ]; then
            echo -e "${GREEN}✓${NC} urls.txt exists with $url_count URL(s)"
            TOTAL_URLS=$((TOTAL_URLS + url_count))
            
            # Display URLs
            echo "  URLs:"
            grep -E -v '^\s*#|^\s*$' "${context_dir}urls.txt" | while read -r url; do
                echo "    - $url"
            done
        else
            echo -e "${RED}✗${NC} urls.txt exists but is empty"
            CONTEXT_VALID=false
            ISSUES="${ISSUES}${context_name}: Empty urls.txt\n"
        fi
    else
        echo -e "${RED}✗${NC} Missing urls.txt"
        CONTEXT_VALID=false
        ISSUES="${ISSUES}${context_name}: Missing urls.txt\n"
    fi
    
    # Check for optional config.yml
    if [ -f "${context_dir}config.yml" ]; then
        # Validate YAML syntax
        if python3 -c "import yaml; yaml.safe_load(open('${context_dir}config.yml'))" 2>/dev/null; then
            echo -e "${GREEN}✓${NC} config.yml exists and is valid YAML"
            
            # Extract key settings
            AUTH_TYPE=$(python3 -c "import yaml; c=yaml.safe_load(open('${context_dir}config.yml')); print(c.get('AUTH_TYPE', 'none'))" 2>/dev/null || echo "none")
            SCAN_TYPE=$(python3 -c "import yaml; c=yaml.safe_load(open('${context_dir}config.yml')); print(c.get('SCAN_TYPE', 'web'))" 2>/dev/null || echo "web")
            SPIDER_DEPTH=$(python3 -c "import yaml; c=yaml.safe_load(open('${context_dir}config.yml')); print(c.get('SPIDER_MAX_DEPTH', 5))" 2>/dev/null || echo "5")
            MAX_DURATION=$(python3 -c "import yaml; c=yaml.safe_load(open('${context_dir}config.yml')); print(c.get('MAX_SCAN_DURATION', 0))" 2>/dev/null || echo "0")
            
            echo "  Settings:"
            echo "    - AUTH_TYPE: $AUTH_TYPE"
            echo "    - SCAN_TYPE: $SCAN_TYPE"
            echo "    - SPIDER_MAX_DEPTH: $SPIDER_DEPTH"
            echo "    - MAX_SCAN_DURATION: $MAX_DURATION"
        else
            echo -e "${RED}✗${NC} config.yml exists but has invalid YAML"
            CONTEXT_VALID=false
            ISSUES="${ISSUES}${context_name}: Invalid YAML in config.yml\n"
        fi
    else
        echo -e "${YELLOW}ℹ${NC} config.yml not present (using defaults)"
    fi
    
    # For API contexts, check for OpenAPI specs
    if [ "$context_name" = "api" ]; then
        openapi_count=$(find "$context_dir" -name "openapi-*.json" 2>/dev/null | wc -l)
        if [ "$openapi_count" -gt 0 ]; then
            echo -e "${GREEN}✓${NC} Found $openapi_count OpenAPI spec(s)"
            find "$context_dir" -name "openapi-*.json" | while read -r spec; do
                spec_name=$(basename "$spec")
                # Validate JSON syntax
                if python3 -c "import json; json.load(open('$spec'))" 2>/dev/null; then
                    echo -e "    ${GREEN}✓${NC} $spec_name (valid JSON)"
                else
                    echo -e "    ${RED}✗${NC} $spec_name (invalid JSON)"
                    CONTEXT_VALID=false
                fi
            done
        else
            echo -e "${YELLOW}ℹ${NC} No OpenAPI specs found in API context"
        fi
    fi
    
    # Update counters
    if [ "$CONTEXT_VALID" = "true" ]; then
        CONTEXTS_VALID=$((CONTEXTS_VALID + 1))
        echo -e "${GREEN}✓ Context $context_name is valid${NC}"
    else
        CONTEXTS_INVALID=$((CONTEXTS_INVALID + 1))
        echo -e "${RED}✗ Context $context_name has issues${NC}"
    fi
done

echo ""
echo "================================================"
echo "Validation Summary"
echo "================================================"
echo -e "Contexts validated: $((CONTEXTS_VALID + CONTEXTS_INVALID))"
echo -e "Valid contexts: ${GREEN}${CONTEXTS_VALID}${NC}"
echo -e "Invalid contexts: ${RED}${CONTEXTS_INVALID}${NC}"
echo -e "Total URLs configured: ${TOTAL_URLS}"

if [ $CONTEXTS_INVALID -gt 0 ]; then
    echo ""
    echo -e "${RED}Issues Found:${NC}"
    echo -e "$ISSUES"
fi

# Check pipeline references
echo ""
echo -e "${BLUE}Checking Pipeline References${NC}"
echo "----------------------------------------"

# Get contexts listed in pipeline
PIPELINE_CONTEXTS=$(grep -o "values: .*" ../ci/child-pipelines/zap-dast.yml | sed 's/values: \[//;s/\]//;s/, /\n/g' | tr -d ' ')

echo "Contexts in pipeline:"
echo "$PIPELINE_CONTEXTS" | while read -r ctx; do
    if [ -d "../ci/scan-contexts/$ctx" ]; then
        echo -e "  ${GREEN}✓${NC} $ctx"
    else
        echo -e "  ${RED}✗${NC} $ctx (directory not found)"
    fi
done

# Final status
echo ""
if [ $CONTEXTS_INVALID -eq 0 ]; then
    echo -e "${GREEN}✅ All scan contexts are properly configured!${NC}"
    exit 0
else
    echo -e "${YELLOW}⚠️  Some contexts have issues. Please review above.${NC}"
    exit 1
fi