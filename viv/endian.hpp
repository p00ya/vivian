// endian.h - byteswapping
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

#ifndef viv_endian_hpp
#define viv_endian_hpp

#include "compat.h"

// \file The Viiiiva config protocol predominantly uses little-endian
// byte-order.  Provide fallback implementations of some of Apple's
// macros/functions for byte-swapping.

#if defined(__APPLE__) && __has_include(<libkern/OSByteOrder.h>)
#include <libkern/OSByteOrder.h>

#pragma clang assume_nonnull begin

namespace {

/// Writes \p x to the memory at `p + offset`, converting to little-endian.
///
/// \return The number of bytes read.
inline size_t
VLWriteLittleInt16(uint8_t *p, size_t offset, uint16_t x) {
  OSWriteLittleInt16(p, offset, x);
  return sizeof(uint16_t);
}

/// Writes \p x to the memory at `p + offset`, converting to little-endian.
///
/// \return The number of bytes read.
inline size_t
VLWriteLittleInt32(uint8_t *p, size_t offset, uint32_t x) {
  OSWriteLittleInt32(p, offset, x);
  return sizeof(uint32_t);
}

} // namespace

#pragma clang assume_nonnull end

#else /* !defined(__APPLE__) || !__has_include(<libkern/OSByteOrder.h>) */

#pragma clang assume_nonnull begin

namespace {

/// Writes \p x to the memory at `p + offset`, converting to little-endian.
///
/// \return The number of bytes read.
inline size_t
VLWriteLittleInt16(uint8_t *p, size_t offset, uint16_t x) {
  p[offset + 0] = static_cast<uint8_t>(x);
  p[offset + 1] = static_cast<uint8_t>(x >> 8);
  return sizeof(uint16_t);
}

/// Writes \p x to the memory at `p + offset`, converting to little-endian.
///
/// \return The number of bytes read.
inline size_t
VLWriteLittleInt32(uint8_t *p, size_t offset, uint32_t x) {
  p[offset + 0] = static_cast<uint8_t>(x);
  p[offset + 1] = static_cast<uint8_t>(x >> 8);
  p[offset + 2] = static_cast<uint8_t>(x >> 16);
  p[offset + 3] = static_cast<uint8_t>(x >> 24);
  return sizeof(uint32_t);
}

/// Returns the little-endian value at `p + offset`, converting to host byte
/// order.
inline uint16_t
OSReadLittleInt16(const uint8_t *p, size_t offset) {
  return static_cast<uint16_t>(p[offset + 0]) | (p[offset + 1] << 8);
}

/// Returns the little-endian value at `p + offset`, converting to host byte
/// order.
inline uint32_t
OSReadLittleInt32(const uint8_t *p, size_t offset) {
  return static_cast<uint32_t>(p[offset + 0]) | (p[offset + 1] << 8) |
         (p[offset + 2] << 16) | (p[offset + 3] << 24);
}

} // namespace

#pragma clang assume_nonnull end

#endif /* defined(__APPLE__) && __has_include(<libkern/OSByteOrder.h>) */

#endif /* viv_endian_hpp */
