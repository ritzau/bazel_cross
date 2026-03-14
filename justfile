default_target := "//..."

# Build all targets
build target=default_target:
    bazel build {{ target }}

# Run all tests
test target=default_target:
    bazel test {{ target }}

# Format all files (C/C++, Starlark, Markdown)
format:
    bazel run //tools/format

# Run clang-tidy on all C/C++ targets
lint target=default_target:
    bazel build --config=clang-tidy {{ target }}

# Run clang-tidy and fail if there are violations
check-lint target=default_target:
    #!/usr/bin/env bash
    set -euo pipefail
    bazel build --config=clang-tidy {{ target }}
    failed=0
    for f in $(find $(bazel info bazel-bin) -name "*.AspectRulesLintClangTidy.out.exit_code"); do
      if [ "$(cat "$f")" != "0" ]; then
        cat "${f%.exit_code}"
        failed=1
      fi
    done
    exit $failed

# Run cpplint
cpplint dir="bazel_cross":
    bazel run //tools/cpplint:cpplint -- --recursive "$(bazel info workspace)/{{ dir }}"

# Regenerate compile_commands.json for clangd
compile-commands:
    bazel run //:refresh_compile_commands

# Run coverage and generate report
coverage target=default_target:
    bazel coverage {{ target }}
