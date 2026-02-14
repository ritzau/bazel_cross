// Copyright 2025 The Bazel Cross Authors.

#include <gtest/gtest.h>
#include "bazel_cross/greet.h"

TEST(HelloTest, BasicAssertions) {
  EXPECT_STREQ(get_greet("World"), "Hello");
}
