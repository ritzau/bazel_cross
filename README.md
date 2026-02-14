# Cross-Compiling Hello World for Linux ARM64 using Bazel and Bzlmod

This example shows how to build a simple Hello World program for Linux ARM64
from a Linux x86_64 (or macOS) host using Bazel with Bzlmod and `toolchains_llvm`, employing a hermetic Chromium sysroot.

## Code Formatting

Format all files (C/C++, Starlark, etc.) with a single command:

```bash
bazel run //tools/format
```

This uses `aspect_rules_lint` to coordinate:

- **C/C++**: `clang-format` (from the hermetic LLVM toolchain).
- **Starlark**: `buildifier` (hermetic pre-built binary).

## Project Structure

```
.
├── MODULE.bazel          # Bzlmod module definition with toolchains_llvm and sysroots
├── BUILD.bazel           # Build target for hello world and platform defs
├── .bazelrc              # Bazel configuration
└── hello.c               # Source file
```

## Files

### hello.c

```c
#include <stdio.h>

int main() {
    printf("Hello, ARM64 World!\n");
    return 0;
}
```

### MODULE.bazel

Configures `toolchains_llvm` (version 1.6.0) and registers Chromium sysroots for Linux ARM64 and AMD64.

### BUILD.bazel

Defines the `cc_binary` target and the `platform` targets (`linux_arm64`, `linux_x86_64`).

### .bazelrc

```
# Configuration for ARM64 cross-compilation
build:linux_arm64 --platforms=//:linux_arm64
```

## Prerequisites

1. Install Bazel 7+ (with Bzlmod support)
2. No manual toolchain installation required! The build uses a hermetic LLVM toolchain.

## Building

### Build for Host (default)

```bash
bazel build //:hello
```

### Build for Linux ARM64

```bash
bazel build --config=linux_arm64 //:hello
```

### Build for Linux x86_64

```bash
bazel build --config=linux_x86_64 //:hello
```

### Build for macOS x86_64

```bash
bazel build --config=macos_x86_64 //:hello
```

## Verification

Check the binary architecture:

```bash
file bazel-bin/hello
# Output: bazel-bin/hello: ELF 64-bit LSB pie executable, ARM aarch64, ...
```

## Sysroots

This project uses Debian Bullseye sysroots from the Chromium project to ensure hermetic builds and compatibility.

## Automatic Updates (Renovate)

A `renovate.json` configuration is included to automate dependency updates (like `toolchains_llvm`).

**To use Renovate:**

1. **GitHub App**: If hosting on GitHub, simply install the [Renovate GitHub App](https://github.com/apps/renovate). It will automatically detect the `renovate.json` and start creating Pull Requests.
2. **Self-Hosted / Local**: You can run Renovate locally using Docker:
   ```bash
   docker run --rm -v "$(pwd):/usr/src/app" renovate/renovate --dry-run=true
   ```
