// vivtime.h - conversion between POSIX and Viiiiva time
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

#ifndef viv_vivtime_h
#define viv_vivtime_h

#ifdef __cplusplus
#include <cstdint>
#include <ctime>
#else
#include <stdint.h>
#include <time.h>
#endif

#ifdef __clang__
#pragma clang assume_nonnull begin
#endif

#ifdef __cplusplus
extern "C" {
using ::std::time_t;
#endif

/// Converts \p posix_time to an ANT+ time.
///
/// \param posix_time Number of seconds (not counting leap seconds) since
/// 1970-01-01Z00:00:00.
extern uint32_t VLGetVivaTimeFromPosix(time_t posix_time);

/// Converts \p viva_time to a POSIX timestamp.
///
/// \param viva_time Number of seconds since 1989-12-31Z00:00:00.
extern time_t VLGetPosixTimeFromViva(uint32_t viva_time);

#ifdef __cplusplus
} // extern "C"
#endif

#ifdef __clang__
#pragma clang assume_nonnull end
#endif

#endif /* viv_time_h */
