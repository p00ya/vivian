// crc.hpp - CRC-8
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

#ifndef viv_crc_hpp
#define viv_crc_hpp

#include <cstdint>
#include <cstdlib>

#include "compat.h"

#pragma clang assume_nonnull begin

namespace viv {

/// Return the CRC used in Viiiiva config packets.
///
/// It is equivalent to CRC with standard parameters:
///
///   width=8, poly=0x07, init=0, refin=false, refout=false, xorout=0,
///   check=0xf4, residue=0.
uint8_t crc(uint8_t const *data, size_t length);

} // namespace viv

#pragma clang assume_nonnull end

#endif /* viv_crc_hpp */
