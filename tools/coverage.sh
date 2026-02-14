#!/bin/bash
set -euo pipefail

# The first argument is the path to grcov, passed by Bazel via 'args'
GRCOV="$1"
shift

# Resolve absolute path to grcov before changing directory
if [[ "$GRCOV" != /* ]]; then
  GRCOV="$PWD/$GRCOV"
fi

# Ensure we are in the workspace root
if [[ -z "${BUILD_WORKSPACE_DIRECTORY:-}" ]]; then
  echo "Error: This script must be run via 'bazel run //tools:coverage'"
  exit 1
fi
cd "$BUILD_WORKSPACE_DIRECTORY"

# Run coverage for all tests (or specified target)
# Default to //bazel_cross/... if no target specified
TARGET="${1:-//bazel_cross/...}"

echo "Running coverage for $TARGET..."

# .bazelrc handles flags: --combined_report=lcov --instrumentation_filter=//
bazel coverage "$TARGET"

# Locate the combined report
COVERAGE_REPORT="bazel-out/_coverage/_coverage_report.dat"

if [ ! -f "$COVERAGE_REPORT" ]; then
    echo "Error: Coverage report not found at $COVERAGE_REPORT"
    exit 1
fi

# grcov enforces .info extension.
TMP_INFO=$(mktemp -t coverage).info
ln -sf "$PWD/$COVERAGE_REPORT" "$TMP_INFO"

echo "Generating HTML report..."
"$GRCOV" "$TMP_INFO" -t html -o coverage_report

rm "$TMP_INFO"

echo "Report generated at coverage_report/index.html"
