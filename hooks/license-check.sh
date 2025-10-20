#!/bin/bash

# License compliance checker for the exploitum project
# Ensures all dependencies have compatible licenses

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'
BOLD='\033[1m'

echo -e "${BOLD}${BLUE}⚖️  License Compliance Check${NC}"
echo -e "${BOLD}${BLUE}══════════════════════════════════════════════════════════${NC}"

# Find the repository root
REPO_ROOT=$(git rev-parse --show-toplevel)
cd "$REPO_ROOT"

ISSUES_FOUND=0
CHECKS_RUN=0

# Define acceptable licenses (add/remove as needed for your project)
ACCEPTABLE_LICENSES=(
    "MIT"
    "Apache-2.0"
    "Apache 2.0"
    "BSD"
    "BSD-2-Clause"
    "BSD-3-Clause"
    "ISC"
    "Unlicense"
    "CC0-1.0"
    "Python Software Foundation"
    "PSF"
)

# Define problematic licenses
PROBLEMATIC_LICENSES=(
    "GPL"
    "AGPL"
    "LGPL"
    "MPL"
    "EPL"
    "CDDL"
    "SSPL"
)

# Function to check if license is acceptable
is_license_acceptable() {
    local license=$1
    
    for acceptable in "${ACCEPTABLE_LICENSES[@]}"; do
        if [[ "$license" == *"$acceptable"* ]]; then
            return 0
        fi
    done
    
    return 1
}

# Function to check if license is problematic
is_license_problematic() {
    local license=$1
    
    for problematic in "${PROBLEMATIC_LICENSES[@]}"; do
        if [[ "$license" == *"$problematic"* ]]; then
            return 0
        fi
    done
    
    return 1
}

# Check project license
echo -e "${BOLD}Project License Check${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━"

if [ -f "LICENSE" ]; then
    echo -e "${GREEN}✓ LICENSE file found${NC}"
    
    # Try to identify the license type
    if grep -i "MIT License" LICENSE >/dev/null 2>&1; then
        echo -e "  ${BLUE}License type: MIT${NC}"
    elif grep -i "Apache License" LICENSE >/dev/null 2>&1; then
        echo -e "  ${BLUE}License type: Apache 2.0${NC}"
    elif grep -i "BSD" LICENSE >/dev/null 2>&1; then
        echo -e "  ${BLUE}License type: BSD${NC}"
    else
        echo -e "  ${YELLOW}⚠ License type not automatically detected${NC}"
        ISSUES_FOUND=$((ISSUES_FOUND + 1))
    fi
elif [ -f "LICENSE.txt" ] || [ -f "LICENSE.md" ]; then
    echo -e "${GREEN}✓ License file found${NC}"
else
    echo -e "${RED}❌ No LICENSE file found${NC}"
    echo -e "  ${YELLOW}Consider adding a LICENSE file to clarify usage terms${NC}"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
fi

CHECKS_RUN=$((CHECKS_RUN + 1))

# Python dependencies license check
if [ -f "requirements.txt" ] || [ -f "pyproject.toml" ] || [ -f "setup.py" ]; then
    echo -e "${BOLD}Python Dependencies License Check${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Check if pip-licenses is available
    if command -v pip-licenses >/dev/null 2>&1; then
        echo -e "${BLUE}Checking Python package licenses...${NC}"
        
        # Generate license report
        PYTHON_LICENSES=$(pip-licenses --format=json 2>/dev/null || echo "[]")
        
        if [ "$PYTHON_LICENSES" != "[]" ]; then
            echo "$PYTHON_LICENSES" | python3 -c "
import sys, json
data = json.load(sys.stdin)
issues = 0
for pkg in data:
    license = pkg.get('License', 'Unknown')
    name = pkg.get('Name', 'Unknown')
    
    if 'GPL' in license or 'AGPL' in license:
        print(f'  ❌ {name}: {license} (potentially problematic)')
        issues += 1
    elif license == 'Unknown' or license == 'UNKNOWN':
        print(f'  ⚠ {name}: License unknown')
        issues += 1
    elif any(acceptable in license for acceptable in ['MIT', 'Apache', 'BSD', 'ISC']):
        print(f'  ✓ {name}: {license}')
    else:
        print(f'  ⚠ {name}: {license} (review needed)')
        issues += 1

sys.exit(issues)
" && python_license_issues=0 || python_license_issues=$?
        
            ISSUES_FOUND=$((ISSUES_FOUND + python_license_issues))
        else
            echo -e "  ${YELLOW}⚠ No Python packages found or pip-licenses failed${NC}"
        fi
    else
        echo -e "  ${YELLOW}⚠ pip-licenses not installed${NC}"
        echo -e "  ${BLUE}Install with: pip install pip-licenses${NC}"
        
        # Fallback: check requirements.txt for known problematic packages
        if [ -f "requirements.txt" ]; then
            echo -e "  ${BLUE}Performing basic requirements.txt scan...${NC}"
            
            # Known packages with GPL licenses
            GPL_PACKAGES=("mysql-python" "PyQt5" "PyQt6" "GPL")
            
            for pkg in "${GPL_PACKAGES[@]}"; do
                if grep -i "$pkg" requirements.txt >/dev/null 2>&1; then
                    echo -e "    ${RED}❌ Found potentially problematic package: $pkg${NC}"
                    ISSUES_FOUND=$((ISSUES_FOUND + 1))
                fi
            done
        fi
    fi
    
    CHECKS_RUN=$((CHECKS_RUN + 1))
fi

# Node.js dependencies license check
if [ -f "package.json" ]; then
    echo -e "${BOLD}Node.js Dependencies License Check${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Check if license-checker is available
    if command -v license-checker >/dev/null 2>&1; then
        echo -e "${BLUE}Checking Node.js package licenses...${NC}"
        
        cd frontend 2>/dev/null || true
        
        # Run license checker
        LICENSE_OUTPUT=$(license-checker --json 2>/dev/null || echo "{}")
        
        if [ "$LICENSE_OUTPUT" != "{}" ]; then
            echo "$LICENSE_OUTPUT" | python3 -c "
import sys, json
data = json.load(sys.stdin)
issues = 0

for pkg_name, pkg_info in data.items():
    licenses = pkg_info.get('licenses', 'Unknown')
    
    if isinstance(licenses, list):
        license_str = ', '.join(licenses)
    else:
        license_str = licenses
    
    pkg_name_clean = pkg_name.split('@')[0]
    
    if any(problematic in license_str for problematic in ['GPL', 'AGPL', 'LGPL']):
        print(f'  ❌ {pkg_name_clean}: {license_str} (potentially problematic)')
        issues += 1
    elif license_str in ['Unknown', 'UNLICENSED']:
        print(f'  ⚠ {pkg_name_clean}: No license specified')
        issues += 1
    elif any(acceptable in license_str for acceptable in ['MIT', 'Apache', 'BSD', 'ISC']):
        print(f'  ✓ {pkg_name_clean}: {license_str}')
    else:
        print(f'  ⚠ {pkg_name_clean}: {license_str} (review needed)')

sys.exit(issues)
" && node_license_issues=0 || node_license_issues=$?
        
            ISSUES_FOUND=$((ISSUES_FOUND + node_license_issues))
        else
            echo -e "  ${YELLOW}⚠ No Node.js packages found or license-checker failed${NC}"
        fi
        
        cd "$REPO_ROOT"
    elif [ -f "frontend/package.json" ] || [ -f "package.json" ]; then
        echo -e "  ${YELLOW}⚠ license-checker not installed${NC}"
        echo -e "  ${BLUE}Install with: npm install -g license-checker${NC}"
    fi
    
    CHECKS_RUN=$((CHECKS_RUN + 1))
fi

# Docker base image license check
if [ -f "Dockerfile" ]; then
    echo -e "${BOLD}Docker Base Image License Check${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    echo -e "${BLUE}Checking Docker base images...${NC}"
    
    BASE_IMAGES=$(grep -i "^FROM " Dockerfile | awk '{print $2}' | head -5)
    
    for image in $BASE_IMAGES; do
        # Common images with known licenses
        if [[ "$image" == *"alpine"* ]]; then
            echo -e "  ${GREEN}✓ $image: MIT-style (Alpine Linux)${NC}"
        elif [[ "$image" == *"ubuntu"* ]] || [[ "$image" == *"debian"* ]]; then
            echo -e "  ${GREEN}✓ $image: Multiple compatible licenses${NC}"
        elif [[ "$image" == *"centos"* ]] || [[ "$image" == *"rhel"* ]]; then
            echo -e "  ${YELLOW}⚠ $image: Review Red Hat licensing terms${NC}"
            ISSUES_FOUND=$((ISSUES_FOUND + 1))
        else
            echo -e "  ${YELLOW}⚠ $image: License unknown - manual review needed${NC}"
            ISSUES_FOUND=$((ISSUES_FOUND + 1))
        fi
    done
    
    CHECKS_RUN=$((CHECKS_RUN + 1))
fi

# Check for copyright notices in source files
echo -e "${BOLD}Copyright Notice Check${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━"

SOURCE_FILES=$(find . -name "*.py" -o -name "*.js" -o -name "*.ts" | grep -v node_modules | grep -v .git | head -10)

if [ -n "$SOURCE_FILES" ]; then
    FILES_WITH_COPYRIGHT=0
    TOTAL_SOURCE_FILES=0
    
    for file in $SOURCE_FILES; do
        TOTAL_SOURCE_FILES=$((TOTAL_SOURCE_FILES + 1))
        
        if grep -i "copyright\|©\|(c)" "$file" >/dev/null 2>&1; then
            FILES_WITH_COPYRIGHT=$((FILES_WITH_COPYRIGHT + 1))
        fi
    done
    
    COPYRIGHT_PERCENTAGE=$((FILES_WITH_COPYRIGHT * 100 / TOTAL_SOURCE_FILES))
    
    if [ $COPYRIGHT_PERCENTAGE -lt 10 ]; then
        echo -e "  ${YELLOW}⚠ Only $COPYRIGHT_PERCENTAGE% of source files have copyright notices${NC}"
        echo -e "  ${BLUE}Consider adding copyright headers to important files${NC}"
    else
        echo -e "  ${GREEN}✓ $COPYRIGHT_PERCENTAGE% of source files have copyright notices${NC}"
    fi
else
    echo -e "  ${BLUE}No source files found to check${NC}"
fi

CHECKS_RUN=$((CHECKS_RUN + 1))

# Summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${BOLD}License Compliance Summary${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ $ISSUES_FOUND -eq 0 ]; then
    echo -e "${GREEN}✅ All $CHECKS_RUN license checks passed!${NC}"
    echo -e "${GREEN}   No license compliance issues detected.${NC}"
else
    echo -e "${YELLOW}⚠️  Found $ISSUES_FOUND potential license issue(s) out of $CHECKS_RUN checks${NC}"
    echo ""
    echo -e "${BLUE}💡 License Compliance Tips:${NC}"
    echo "  • Review all third-party dependencies"
    echo "  • Maintain a license inventory"
    echo "  • Use tools like FOSSA or WhiteSource for enterprise needs"
    echo "  • Consider legal review for commercial projects"
    echo "  • Keep license information up to date"
fi

echo ""
echo -e "${BLUE}📋 Recommended Tools:${NC}"
echo "  • pip install pip-licenses (Python)"
echo "  • npm install -g license-checker (Node.js)"
echo "  • GitHub's licensed tool"
echo "  • FOSSA CLI for enterprise"

exit 0