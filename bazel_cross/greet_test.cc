// Copyright 2025 The Bazel Cross Authors.

#include "bazel_cross/greet.h"

#include <gtest/gtest.h>

TEST(HelloTest, BasicAssertions) { EXPECT_STREQ(get_greet("World"), "Hello"); }
