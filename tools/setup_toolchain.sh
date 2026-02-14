#!/bin/bash
set -euo pipefail

# Ensure we are in the workspace root
cd "${BUILD_WORKSPACE_DIRECTORY:-$(git rev-parse --show-toplevel)}"

TARGET_DIR="tools/bin"
mkdir -p "$TARGET_DIR"

# Determine platform
OS=$(uname -s)
ARCH=$(uname -m)

if [ "$OS" == "Linux" ]; then
    if [ "$ARCH" == "x86_64" ]; then
        TARGET="@llvm_toolchain//:all-components-x86_64-linux"
    elif [ "$ARCH" == "aarch64" ]; then
        TARGET="@llvm_toolchain//:all-components-aarch64-linux"
    else
        echo "Unsupported Linux architecture: $ARCH"
        exit 1
    fi
elif [ "$OS" == "Darwin" ]; then
    # Bazel toolchain often provides x86_64-darwin which works on arm64 via Rosetta or is universal
    TARGET="@llvm_toolchain//:all-components-x86_64-darwin"
else
    echo "Unsupported OS: $OS"
    exit 1
fi

echo "Building toolchain components for $OS $ARCH ($TARGET)..."
bazel build "$TARGET"

# Resolve the path to the toolchain bin directory
# We use bazel cquery to find the output path of a known file
# and ensuring it is absolute
TOOLCHAIN_BIN=$(bazel cquery @llvm_toolchain//:bin/clang-format --output=files | xargs dirname)
if [[ "$TOOLCHAIN_BIN" != /* ]]; then
  TOOLCHAIN_BIN="$PWD/$TOOLCHAIN_BIN"
fi

echo "toolchain bin: $TOOLCHAIN_BIN"

# Symlink tools
TOOLS=(clang-format clang-tidy clangd llvm-cov llvm-profdata lldb)

for tool in "${TOOLS[@]}"; do
  if [ -f "$TOOLCHAIN_BIN/$tool" ]; then
    ln -sf "$TOOLCHAIN_BIN/$tool" "$TARGET_DIR/$tool"
    echo "Symlinked $tool to $TARGET_DIR/$tool"
  else
    if [ "$tool" == "lldb" ] && [ "$OS" == "Darwin" ]; then
        echo "Note: lldb not found (expected on macOS due to code signing). Use system /usr/bin/lldb."
    else
        echo "Warning: $tool not found in $TOOLCHAIN_BIN"
    fi
  fi
done

# Handle clang/clang++ specifically
if [ -f "$TOOLCHAIN_BIN/clang" ]; then
  ln -sf "$TOOLCHAIN_BIN/clang" "$TARGET_DIR/clang"
  ln -sf "$TOOLCHAIN_BIN/clang++" "$TARGET_DIR/clang++"
  echo "Symlinked clang and clang++"
elif [ -f "$TOOLCHAIN_BIN/clang-cpp" ]; then
  # On some distributions, clang-cpp is the main driver
  ln -sf "$TOOLCHAIN_BIN/clang-cpp" "$TARGET_DIR/clang"
  ln -sf "$TOOLCHAIN_BIN/clang-cpp" "$TARGET_DIR/clang++"
  echo "Symlinked clang and clang++ (via clang-cpp)"
else
  echo "Warning: Could not find clang binary to symlink"
fi

if [ -f "$TOOLCHAIN_BIN/llvm-symbolizer" ]; then
    ln -sf "$TOOLCHAIN_BIN/llvm-symbolizer" "$TARGET_DIR/llvm-symbolizer"
fi

echo "Building hermetic jq..."
bazel build //tools/jq

# Resolving jq binary
JQ_BIN=$(bazel cquery //tools/jq --output=files | xargs dirname)
if [[ "$JQ_BIN" != /* ]]; then
  JQ_BIN="$PWD/$JQ_BIN"
fi

if [ -f "$JQ_BIN/jq" ]; then
    ln -sf "$JQ_BIN/jq" "$TARGET_DIR/jq"
    echo "Symlinked jq to $TARGET_DIR/jq"
else
    echo "Warning: jq binary not found in $JQ_BIN"
fi

echo ""
echo "Done! Add this to your shell profile (e.g. ~/.zshrc):"
echo "export PATH=\"\$PWD/$TARGET_DIR:\$PATH\""
