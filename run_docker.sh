#!/bin/bash

# Ensure cache directory exists on host
mkdir -p ~/.cache/bazel_cache/linux

# Run container with cache mount
# specific to user's UID to avoid permission issues
# We mount a sub-directory for linux to avoid sharing artifacts with macOS host
docker run -it --rm \
  -v "$(pwd)":/src \
  -v "${HOME}/.cache/bazel_cache/linux":/home/ubuntu/.cache/bazel_cache \
  bazel-cross-build \
  /bin/bash
