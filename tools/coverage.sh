#!/bin/bash
set -euo pipefail

# Run coverage for all tests (or specified target)
TARGET="${1:-//:hello_test}"
echo "Running coverage for $TARGET..."

# .bazelrc handles flags: --combined_report=lcov --instrumentation_filter=//
bazel coverage "$TARGET"

# Locate the combined report
# It's typically in bazel-out/_coverage/_coverage_report.dat
COVERAGE_REPORT="bazel-out/_coverage/_coverage_report.dat"

if [ ! -f "$COVERAGE_REPORT" ]; then
    echo "Error: Coverage report not found at $COVERAGE_REPORT"
    exit 1
fi

# grcov enforces .info extension.
# We symlink to a temp location to keep the workspace clean.
TMP_INFO=$(mktemp /tmp/coverage.XXXXXX.info)
ln -sf "$PWD/$COVERAGE_REPORT" "$TMP_INFO"

echo "Generating HTML report..."
tools/bin/grcov "$TMP_INFO" -t html -o coverage_report

rm "$TMP_INFO"

echo "Report generated at coverage_report/index.html"
