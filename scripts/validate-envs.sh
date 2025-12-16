#!/bin/bash
#
# =============================================================================
# Environment Variables Validation Script
# =============================================================================
#
# DESCRIPTION:
#   Validates consistency of environment variables across the project:
#   - .env.example (source of truth for host-side configuration)
#   - compose.base.yml (single source of truth for container environment mappings)
#   - Shell scripts (required env vars declared with : "${VAR:?}")
#   - Kubernetes Helm chart (k8s/values.example.yaml and templates)
#
# VALIDATIONS PERFORMED:
#   1. Variables in compose.base.yml ${VAR} refs must be in .env.example
#   2. Required vars in shell scripts must be defined somewhere:
#      - In .env.example (for host-side scripts)
#      - Or in compose.base.yml container environment (for container scripts)
#   3. K8s template .Values.env.* refs must be in k8s/values.example.yaml
#   4. Warnings for unused/undeclared variables
#
# USAGE:
#   SCAN_DIRS="./scripts" ./scripts/validate-envs.sh
#
# PARAMETERS:
#   SCAN_DIRS  Comma-separated list of directories to scan for env vars
#              Example: SCAN_DIRS="./scripts,./server"
#
# SHELL SCRIPT CONVENTION:
#   To declare required env vars in shell scripts, use this pattern at the top:
#     : "${VAR_NAME:?Required env var VAR_NAME is not set}"
#   This serves as both documentation and runtime validation.
#
# EXIT CODES:
#   0 - All validations passed (may have warnings)
#   1 - Validation failed with errors
#
# =============================================================================

set -e

# Script parameters (can be set via environment variables)
SCAN_DIRS="${SCAN_DIRS:-}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}  Environment Variables Validation${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

# Track validation status
HAS_ERRORS=0
HAS_WARNINGS=0

# Temporary files for analysis
USED_VARS_FILE=$(mktemp)
ENV_EXAMPLE_VARS_FILE=$(mktemp)
DOCKER_COMPOSE_VARS_FILE=$(mktemp)
DOCKER_COMPOSE_CONTAINER_VARS_FILE=$(mktemp)
SCRIPT_REQUIRED_VARS_FILE=$(mktemp)
K8S_VARS_FILE=$(mktemp)

# Cleanup on exit
cleanup_files() {
  rm -f "$USED_VARS_FILE" "$ENV_EXAMPLE_VARS_FILE" "$DOCKER_COMPOSE_VARS_FILE" \
        "$DOCKER_COMPOSE_CONTAINER_VARS_FILE" "$SCRIPT_REQUIRED_VARS_FILE" \
        "$K8S_VARS_FILE" "$K8S_VALUES_VARS_FILE" 2>/dev/null || true
}
trap cleanup_files EXIT
K8S_VALUES_VARS_FILE=""  # Will be set later

echo -e "${YELLOW}Step 1: Extracting environment variables used in code...${NC}"

# Check if SCAN_DIRS is provided
if [ -z "$SCAN_DIRS" ]; then
  echo -e "${YELLOW}⚠ No SCAN_DIRS provided, skipping code scanning...${NC}"
  echo -e "${YELLOW}  Set SCAN_DIRS env var with comma-separated directories to scan${NC}"
  echo -e "${YELLOW}  Example: SCAN_DIRS=\"./server,./scripts\" ./scripts/validate-envs.sh${NC}"
  TOTAL_USED=0
else
  # Convert comma-separated directories to array
  IFS=',' read -ra DIRS_ARRAY <<< "$SCAN_DIRS"

  # Extract env vars from Python code
  # Patterns: os.getenv("VAR"), os.environ.get("VAR"), os.environ["VAR"]
  for dir in "${DIRS_ARRAY[@]}"; do
    dir=$(echo "$dir" | xargs)  # Trim whitespace
    if [ -d "$dir" ]; then
      find "$dir" -type f -name "*.py" -exec grep -oh \
        -e 'os\.getenv([^)]*' \
        -e 'os\.environ\.get([^)]*' \
        -e 'os\.environ\[[^]]*' \
        {} + 2>/dev/null | \
        grep -oE '"[A-Z_][A-Z0-9_]*"|'"'"'[A-Z_][A-Z0-9_]*'"'"'' | \
        tr -d '"'"'" >> "$USED_VARS_FILE" || true
    else
      echo -e "${YELLOW}  ⚠ Directory not found: ${dir}${NC}"
    fi
  done

  # Extract env vars from Shell scripts
  # Only detect explicitly declared env vars using the pattern: : "${VAR_NAME:?..."
  # This pattern is used at the top of scripts to document and validate required env vars.
  for dir in "${DIRS_ARRAY[@]}"; do
    dir=$(echo "$dir" | xargs)  # Trim whitespace
    if [ -d "$dir" ]; then
      find "$dir" -type f -name "*.sh" -exec grep -oh \
        ': "\${[A-Z_][A-Z0-9_]*:?' \
        {} + 2>/dev/null | \
        sed -E 's/: "\$\{([A-Z_][A-Z0-9_]*):?.*/\1/' >> "$USED_VARS_FILE" || true
    fi
  done

  # Remove duplicates
  sort -u "$USED_VARS_FILE" -o "$USED_VARS_FILE"
  TOTAL_USED=$(wc -l < "$USED_VARS_FILE")
fi

# Filter out common false positives (framework/system variables)

# System/Shell variables
sed -i '/^NODE_ENV$/d' "$USED_VARS_FILE" 2>/dev/null || true
sed -i '/^PATH$/d' "$USED_VARS_FILE" 2>/dev/null || true
sed -i '/^HOME$/d' "$USED_VARS_FILE" 2>/dev/null || true
sed -i '/^USER$/d' "$USED_VARS_FILE" 2>/dev/null || true
sed -i '/^PWD$/d' "$USED_VARS_FILE" 2>/dev/null || true
sed -i '/^PORT$/d' "$USED_VARS_FILE" 2>/dev/null || true

# Build/Test environment variables
sed -i '/^DEBUG$/d' "$USED_VARS_FILE" 2>/dev/null || true
sed -i '/^ANALYZE$/d' "$USED_VARS_FILE" 2>/dev/null || true
sed -i '/^PLAYWRIGHT_BASE_URL$/d' "$USED_VARS_FILE" 2>/dev/null || true
sed -i '/^GITHUB_ACTIONS$/d' "$USED_VARS_FILE" 2>/dev/null || true

# Single letter variables (likely false positives)
sed -i '/^N$/d' "$USED_VARS_FILE" 2>/dev/null || true

# Placeholder variable names from comments/documentation
sed -i '/^VAR_NAME$/d' "$USED_VARS_FILE" 2>/dev/null || true
sed -i '/^VAR$/d' "$USED_VARS_FILE" 2>/dev/null || true

# Container-internal env vars (set by docker-compose, not directly from .env.example)
# These are mapped from .env vars to container env vars in docker-compose.yml
# (Add here if relevant)

if [ -n "$SCAN_DIRS" ]; then
  TOTAL_USED=$(wc -l < "$USED_VARS_FILE")
  echo -e "${GREEN}✓ Found ${TOTAL_USED} unique environment variables in code${NC}"
fi
echo ""

echo -e "${YELLOW}Step 2: Extracting variables from .env.example...${NC}"

# Extract vars from .env.example
grep -E '^[A-Z_][A-Z0-9_]*=' .env.example 2>/dev/null | \
  cut -d'=' -f1 | \
  sort -u > "$ENV_EXAMPLE_VARS_FILE" || true

TOTAL_ENV_EXAMPLE=$(wc -l < "$ENV_EXAMPLE_VARS_FILE")
echo -e "${GREEN}✓ Found ${TOTAL_ENV_EXAMPLE} variables in .env.example${NC}"
echo ""

echo -e "${YELLOW}Step 3: Extracting variables from compose.base.yml...${NC}"

# Extract from compose.base.yml (single source of truth for env vars)
# Variables referenced as ${VAR} or ${VAR:-default}
# Exclude double-dollar-sign variables ($${VAR}) which are escaped and not substituted
COMPOSE_BASE_FILE="./compose.base.yml"
if [ -f "$COMPOSE_BASE_FILE" ]; then
  grep -oE '\$\{[A-Z_][A-Z0-9_]*(:-[^}]*)?\}' "$COMPOSE_BASE_FILE" 2>/dev/null | \
    grep -v '^\$\$' | \
    sed -E 's/\$\{([A-Z_][A-Z0-9_]*)(:-[^}]*)?\}/\1/' | \
    sort -u > "$DOCKER_COMPOSE_VARS_FILE" || true
else
  echo -e "${YELLOW}⚠ compose.base.yml not found${NC}"
  touch "$DOCKER_COMPOSE_VARS_FILE"
fi

TOTAL_DOCKER=$(wc -l < "$DOCKER_COMPOSE_VARS_FILE")
echo -e "${GREEN}✓ Found ${TOTAL_DOCKER} variables referenced in compose.base.yml${NC}"
echo ""

echo -e "${YELLOW}Step 4: Extracting container-internal env vars from compose.base.yml...${NC}"

# Extract container-internal env vars from compose.base.yml (single source of truth)
# These are the KEY part of "KEY: value" in environment sections
# They will be available INSIDE containers
if [ -f "$COMPOSE_BASE_FILE" ]; then
  grep -E '^\s+[A-Z_][A-Z0-9_]*:\s' "$COMPOSE_BASE_FILE" 2>/dev/null | \
    grep -v '^\s*#' | \
    sed -E 's/.*\s+([A-Z_][A-Z0-9_]*):.*/\1/' | \
    sort -u > "$DOCKER_COMPOSE_CONTAINER_VARS_FILE" || true
else
  touch "$DOCKER_COMPOSE_CONTAINER_VARS_FILE"
fi

TOTAL_CONTAINER_VARS=$(wc -l < "$DOCKER_COMPOSE_CONTAINER_VARS_FILE")
echo -e "${GREEN}✓ Found ${TOTAL_CONTAINER_VARS} container-internal env vars in compose.base.yml${NC}"
echo ""

echo -e "${YELLOW}Step 5: Extracting required env vars declared in shell scripts...${NC}"

# Extract required env vars declared in shell scripts using pattern: : "${VAR:?"
# This is the standard bash idiom for required env var validation
if [ -n "$SCAN_DIRS" ]; then
  for dir in "${DIRS_ARRAY[@]}"; do
    dir=$(echo "$dir" | xargs)  # Trim whitespace
    if [ -d "$dir" ]; then
      find "$dir" -type f -name "*.sh" -exec grep -oh \
        ': "\${[A-Z_][A-Z0-9_]*:?' \
        {} + 2>/dev/null | \
        sed -E 's/: "\$\{([A-Z_][A-Z0-9_]*):?.*/\1/' >> "$SCRIPT_REQUIRED_VARS_FILE" || true
    fi
  done

  # Remove duplicates and filter out placeholder var names
  sort -u "$SCRIPT_REQUIRED_VARS_FILE" -o "$SCRIPT_REQUIRED_VARS_FILE"
  sed -i '/^VAR$/d' "$SCRIPT_REQUIRED_VARS_FILE" 2>/dev/null || true
  sed -i '/^VAR_NAME$/d' "$SCRIPT_REQUIRED_VARS_FILE" 2>/dev/null || true
  TOTAL_SCRIPT_REQUIRED_VARS=$(wc -l < "$SCRIPT_REQUIRED_VARS_FILE")
  echo -e "${GREEN}✓ Found ${TOTAL_SCRIPT_REQUIRED_VARS} required env vars declared in shell scripts${NC}"
else
  echo -e "${YELLOW}⚠ No SCAN_DIRS provided, skipping shell script analysis...${NC}"
  touch "$SCRIPT_REQUIRED_VARS_FILE"
fi
echo ""

echo -e "${YELLOW}Step 6: Extracting variables from Kubernetes Helm chart...${NC}"

K8S_DIR="k8s"
K8S_VALUES_EXAMPLE="$K8S_DIR/values.example.yaml"
K8S_VALUES_VARS_FILE=$(mktemp)

if [ -d "$K8S_DIR" ]; then
  # Extract env var references from k8s templates: .Values.env.<section>.<VAR_NAME>
  # Pattern: .Values.env.llm.VLLM_MODEL, .Values.env.common.DEV_MODE, etc.
  find "$K8S_DIR/templates/" -type f \( -name "*.yaml" -o -name "*.yml" \) -exec grep -oh \
    '\.Values\.env\.[a-zA-Z]*\.[A-Z_][A-Z0-9_]*' \
    {} + 2>/dev/null | \
    sed -E 's/\.Values\.env\.([a-zA-Z]*)\.([A-Z_][A-Z0-9_]*)/\1.\2/' | \
    sort -u > "$K8S_VARS_FILE" || true

  TOTAL_K8S=$(wc -l < "$K8S_VARS_FILE")
  echo -e "${GREEN}✓ Found ${TOTAL_K8S} env var references in k8s templates${NC}"

  # Extract env vars defined in values.example.yaml under env: section
  # Pattern: env.llm.VLLM_MODEL: "value"
  if [ -f "$K8S_VALUES_EXAMPLE" ]; then
    # Parse YAML env section - extract section.VAR_NAME pairs
    awk '
      /^env:/ { in_env=1; next }
      /^[a-zA-Z]/ && !/^  / { in_env=0 }
      in_env && /^  [a-zA-Z]+:/ { section=$1; gsub(/:/, "", section); next }
      in_env && /^    [A-Z_][A-Z0-9_]*:/ {
        var=$1; gsub(/:/, "", var)
        print section "." var
      }
    ' "$K8S_VALUES_EXAMPLE" | sort -u > "$K8S_VALUES_VARS_FILE"

    TOTAL_K8S_VALUES=$(wc -l < "$K8S_VALUES_VARS_FILE")
    echo -e "${GREEN}✓ Found ${TOTAL_K8S_VALUES} env vars defined in values.example.yaml${NC}"
  else
    echo -e "${YELLOW}⚠ values.example.yaml not found${NC}"
    touch "$K8S_VALUES_VARS_FILE"
  fi
else
  echo -e "${YELLOW}⚠ WARNING: Directory ${K8S_DIR} not found, skipping...${NC}"
  touch "$K8S_VARS_FILE"
  touch "$K8S_VALUES_VARS_FILE"
  TOTAL_K8S=0
fi
echo ""

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}  Validation Results${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

# Check: Variables used in code but missing from .env.example
if [ -n "$SCAN_DIRS" ]; then
  echo -e "${YELLOW}Checking: Variables in code but missing from .env.example...${NC}"
  MISSING_IN_ENV_EXAMPLE=$(comm -23 "$USED_VARS_FILE" "$ENV_EXAMPLE_VARS_FILE")

  if [ -n "$MISSING_IN_ENV_EXAMPLE" ]; then
    echo -e "${RED}✗ ERROR: The following variables are used in code but not in .env.example:${NC}"
    echo "$MISSING_IN_ENV_EXAMPLE" | sed 's/^/  - /'
    echo ""
    HAS_ERRORS=1
  else
    echo -e "${GREEN}✓ All code variables are in .env.example${NC}"
    echo ""
  fi
else
  echo -e "${YELLOW}⚠ Skipping code variable check (no SCAN_DIRS provided)${NC}"
  echo ""
fi

# Check: Variables in compose.base.yml not in .env.example
echo -e "${YELLOW}Checking: Variables in compose.base.yml but missing from .env.example...${NC}"
MISSING_DOCKER=$(comm -23 "$DOCKER_COMPOSE_VARS_FILE" "$ENV_EXAMPLE_VARS_FILE")

# Filter out CI-specific variables (set dynamically by GitHub Actions workflows, not user-configurable)
# These are set by workflow inputs and should NOT be in .env.example
# Add more CI-only vars here if needed in the future

if [ -n "$MISSING_DOCKER" ]; then
  echo -e "${RED}✗ ERROR: The following variables are in compose.base.yml but not in .env.example:${NC}"
  echo "$MISSING_DOCKER" | sed 's/^/  - /'
  echo ""
  HAS_ERRORS=1
else
  echo -e "${GREEN}✓ All compose.base.yml variables are in .env.example${NC}"
  echo ""
fi

# Check: Required vars declared in shell scripts must be set somewhere
# - Either in .env.example (for host-side scripts)
# - Or in docker-compose container environment (for container scripts)
if [ -s "$SCRIPT_REQUIRED_VARS_FILE" ]; then
  echo -e "${YELLOW}Checking: Shell script required vars are defined...${NC}"

  # Combine .env.example vars and docker-compose container vars
  COMBINED_VARS_FILE=$(mktemp)
  cat "$ENV_EXAMPLE_VARS_FILE" "$DOCKER_COMPOSE_CONTAINER_VARS_FILE" | sort -u > "$COMBINED_VARS_FILE"

  MISSING_VARS=$(comm -23 "$SCRIPT_REQUIRED_VARS_FILE" "$COMBINED_VARS_FILE")

  rm -f "$COMBINED_VARS_FILE"

  if [ -n "$MISSING_VARS" ]; then
    echo -e "${RED}✗ ERROR: The following env vars are required by shell scripts but NOT defined anywhere:${NC}"
    echo "$MISSING_VARS" | sed 's/^/  - /'
    echo -e "${YELLOW}  Fix: Add to .env.example (host scripts) or docker-compose environment (container scripts)${NC}"
    echo ""
    HAS_ERRORS=1
  else
    echo -e "${GREEN}✓ All shell script required vars are defined${NC}"
    echo ""
  fi

  # Check reverse: Container vars in compose.base.yml that shell scripts don't declare (warning only)
  echo -e "${YELLOW}Checking: compose.base.yml container vars are declared in shell scripts...${NC}"
  echo -e "${YELLOW}  File checked: ${COMPOSE_BASE_FILE}${NC}"
fi

# Check: Variables in k8s templates must be defined in values.example.yaml
if [ -s "$K8S_VARS_FILE" ] && [ -s "$K8S_VALUES_VARS_FILE" ]; then
  echo -e "${YELLOW}Checking: k8s template env vars are defined in values.example.yaml...${NC}"
  MISSING_K8S=$(comm -23 "$K8S_VARS_FILE" "$K8S_VALUES_VARS_FILE")

  if [ -n "$MISSING_K8S" ]; then
    echo -e "${RED}✗ ERROR: The following env vars are used in k8s templates but NOT defined in values.example.yaml:${NC}"
    echo "$MISSING_K8S" | sed 's/^/  - .Values.env./'
    echo -e "${YELLOW}  Fix: Add these to the 'env:' section in k8s/values.example.yaml${NC}"
    echo ""
    HAS_ERRORS=1
  else
    echo -e "${GREEN}✓ All k8s template env vars are defined in values.example.yaml${NC}"
    echo ""
  fi

  # Check reverse: vars defined in values.example.yaml but not used in templates
  echo -e "${YELLOW}Checking: values.example.yaml env vars are used in k8s templates...${NC}"
  UNUSED_K8S=$(comm -23 "$K8S_VALUES_VARS_FILE" "$K8S_VARS_FILE")

  if [ -n "$UNUSED_K8S" ]; then
    echo -e "${YELLOW}⚠ WARNING: The following env vars are defined in values.example.yaml but not used in k8s templates:${NC}"
    echo "$UNUSED_K8S" | sed 's/^/  - .Values.env./'
    echo -e "${YELLOW}  (These might be unused or referenced differently)${NC}"
    echo ""
    HAS_WARNINGS=1
  else
    echo -e "${GREEN}✓ All values.example.yaml env vars are used in k8s templates${NC}"
    echo ""
  fi
elif [ -d "$K8S_DIR" ]; then
  echo -e "${YELLOW}⚠ Skipping k8s validation (no env vars found)${NC}"
  echo ""
fi

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}  Summary${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

if [ $HAS_ERRORS -eq 0 ] && [ $HAS_WARNINGS -eq 0 ]; then
  echo -e "${GREEN}✓ All checks passed! Environment variables are properly configured.${NC}"
  exit 0
elif [ $HAS_ERRORS -eq 0 ]; then
  echo -e "${YELLOW}⚠ Validation passed with warnings.${NC}"
  exit 0
else
  echo -e "${RED}✗ Validation failed! Please fix the errors above.${NC}"
  exit 1
fi
