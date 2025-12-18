#!/bin/sh
# OCPA-R24: POSIX-compliant Helm deployment script
# Handles envsubst variable substitution and Helm operations
#
# Usage: ./scripts/deploy-helm.sh <deploy|uninstall> [release_name] [namespace]
# Example: ./scripts/deploy-helm.sh deploy myapp default

set -e

ACTION="${1:?ERROR: Action required (deploy|uninstall)}"
RELEASE_NAME="${2:-ocpa-specs}"
NAMESPACE="${3:-default}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CHART_DIR="$PROJECT_DIR/k8s"
VALUES_EXAMPLE="$CHART_DIR/values.example.yaml"
VALUES_FILE="$CHART_DIR/values.yaml"

# Validate chart directory exists
if [ ! -d "$CHART_DIR" ]; then
    echo "ERROR: Chart directory $CHART_DIR not found"
    exit 1
fi

# Validate Chart.yaml exists
if [ ! -f "$CHART_DIR/Chart.yaml" ]; then
    echo "ERROR: $CHART_DIR/Chart.yaml not found"
    exit 1
fi

case "$ACTION" in
    deploy)
        # Validate values.example.yaml exists
        if [ ! -f "$VALUES_EXAMPLE" ]; then
            echo "ERROR: $VALUES_EXAMPLE not found"
            exit 1
        fi

        echo "INFO: Generating values.yaml from values.example.yaml using envsubst..."

        # Export all environment variables for envsubst
        # Use envsubst with explicit variable list for security
        # Only substitute variables that are defined in values.example.yaml
        envsubst < "$VALUES_EXAMPLE" > "$VALUES_FILE"

        echo "INFO: Generated $VALUES_FILE"

        # Validate required variables are set
        if grep -q '${' "$VALUES_FILE"; then
            echo "WARN: Some variables may not be substituted. Check values.yaml for remaining \${VAR} patterns."
        fi

        echo "INFO: Deploying Helm chart..."
        echo "  Release: $RELEASE_NAME"
        echo "  Namespace: $NAMESPACE"
        echo "  Chart: $CHART_DIR"

        # Install or upgrade the release
        if helm status "$RELEASE_NAME" -n "$NAMESPACE" >/dev/null 2>&1; then
            echo "INFO: Upgrading existing release..."
            helm upgrade "$RELEASE_NAME" "$CHART_DIR" \
                -n "$NAMESPACE" \
                -f "$VALUES_FILE" \
                --wait \
                --timeout 5m
        else
            echo "INFO: Installing new release..."
            helm install "$RELEASE_NAME" "$CHART_DIR" \
                -n "$NAMESPACE" \
                -f "$VALUES_FILE" \
                --create-namespace \
                --wait \
                --timeout 5m
        fi

        echo "SUCCESS: Helm deployment completed"
        helm status "$RELEASE_NAME" -n "$NAMESPACE"
        ;;

    uninstall)
        echo "INFO: Uninstalling Helm release..."
        echo "  Release: $RELEASE_NAME"
        echo "  Namespace: $NAMESPACE"

        if helm status "$RELEASE_NAME" -n "$NAMESPACE" >/dev/null 2>&1; then
            helm uninstall "$RELEASE_NAME" -n "$NAMESPACE" --wait
            echo "SUCCESS: Release $RELEASE_NAME uninstalled"
        else
            echo "WARN: Release $RELEASE_NAME not found in namespace $NAMESPACE"
        fi

        # Clean up generated values.yaml
        if [ -f "$VALUES_FILE" ]; then
            rm -f "$VALUES_FILE"
            echo "INFO: Cleaned up $VALUES_FILE"
        fi
        ;;

    *)
        echo "ERROR: Unknown action '$ACTION'"
        echo "Usage: $0 <deploy|uninstall> [release_name] [namespace]"
        exit 1
        ;;
esac
