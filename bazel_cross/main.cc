// Copyright 2025 The Bazel Cross Authors.

#include <iostream>

#include "bazel_cross/greet.h"

int main() {
  int unused_variable = 42;
  const char* result = get_greet("World");
  std::cout << result << std::endl;
  return 0;
}
