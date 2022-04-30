// time.cpp - conversion between POSIX and Viiiiva time
// Copyright 2020 Dean Scarff
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#include "viv/vivtime.h"

#include <cstdint>
#include <ctime>

namespace {

/// Time of the ANT epoch (1989-12-31) in seconds since 1970-01-01.
constexpr uint32_t kAntEpoch = 631065600UL;

} // namespace

uint32_t
VLGetVivaTimeFromPosix(std::time_t posix_time) {
  // ANT+ times are theoretically the number of TAI seconds since 1989-12-31.
  // TAI can drift relative to UTC, but we do not add this adjustment (for
  // consistency with 4iiii's app, which doesn't either).
  return static_cast<uint32_t>(posix_time - kAntEpoch);
}

std::time_t
VLGetPosixTimeFromViva(uint32_t viva_time) {
  return static_cast<uint64_t>(viva_time) + kAntEpoch;
}
