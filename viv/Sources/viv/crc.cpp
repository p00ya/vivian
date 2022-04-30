// crc.cpp - CRC-8
// Copyright Dean Scarff
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

#include "viv/crc.hpp"

#include <array>
#include <cstdint>
#include <cstdlib>

#pragma clang assume_nonnull begin

namespace {

/// CRC-8 polynomial used for Viiiiva config packets.
constexpr uint8_t kPoly = 7;

/// Precomputed CRC for every possible byte value.
using LookupTable = std::array<uint8_t, 256>;

/// Returns the CRC for a single byte.
///
/// \tparam T_poly The (shifted) CRC polynomial.
template <uint8_t T_poly>
constexpr uint8_t
crc8_precalc(uint8_t x) {
  for (int i = 0; i < 8; ++i) {
    // Note this is an unreflected implementation.
    x = x & 0x80 ? (x << 1) ^ T_poly : x << 1;
  }
  return x;
}

/// Returns a lookup table for every byte value, containing the CRC of that
/// byte.
///
/// \tparam T_poly The (shifted) CRC polynomial.
template <uint8_t T_poly>
constexpr LookupTable
crc_init_lookup() {
  LookupTable table;
  for (int i = 0; i < table.size(); ++i) {
    table[i] = crc8_precalc<T_poly>(i);
  }
  return table;
}

} // namespace

namespace viv {

uint8_t
crc(uint8_t const *data, size_t length) {
  static LookupTable const lookup = crc_init_lookup<kPoly>();
  uint8_t crc = 0;
  for (uint8_t const *p = data; p < data + length; ++p) {
    crc = lookup[crc ^ *p];
  }
  return crc;
}

} // namespace viv

#pragma clang assume_nonnull end
