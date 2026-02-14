#!/bin/bash
set -euo pipefail

# Get workspace root
WORKSPACE_ROOT=$(bazel info workspace)
TARGET_DIR="${1:-$WORKSPACE_ROOT/bazel_cross}"

echo "Linting $TARGET_DIR..."
# We use --recursive to verify all files in the target directory
bazel run //tools/cpplint:cpplint -- --recursive "$TARGET_DIR"
