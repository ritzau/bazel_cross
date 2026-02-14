// Copyright 2025 The Bazel Cross Authors.

#include <iostream>

#include "bazel_cross/greet.h"

int main() {
  std::cout << get_greet("World") << std::endl;
  return 0;
}
