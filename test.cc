#include <gtest/gtest.h>
#include "greet.h"

TEST(HelloTest, BasicAssertions) {
  EXPECT_STREQ(get_greet("World"), "Hello");
}
