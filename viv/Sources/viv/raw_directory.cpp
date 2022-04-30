// directory.cpp - description
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

#include "viv/raw_directory.h"

#include <cassert>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <type_traits>

namespace {
/// Expected value for VLDirectoryHeader::version.
constexpr uint8_t kExpectedDirectoryVersion = 1;

/// Expected value for VLDirectoryHeader::time_format.
constexpr uint8_t kExpectedTimeFormat = 0;

/// Expected value for VLDirectoryHeader::record_length.
constexpr uint8_t kExpectedRecordLength = 16;

// This implementation assumes there is no padding between the members of
// VLDirectoryHeader.
static_assert(
    sizeof(VLDirectoryHeader) == 16,
    "VLDirectoryHeader must be packed; coax the compiler to pack it");

static_assert(
    std::is_pod<VLDirectoryHeader>::value,
    "VLDirectoryHeader must be POD; check its definition");

// This implementation assumes there is no padding between the members of
// VLRawDirectoryEntry.
static_assert(
    sizeof(VLRawDirectoryEntry) == 16,
    "VLRawDirectoryEntry must be packed; coax the compiler to pack it");

static_assert(
    std::is_pod<VLRawDirectoryEntry>::value,
    "VLRawDirectoryEntry must be POD; check its definition");

} // namespace

int
VLReadDirectoryHeader(
    VLDirectoryHeader *dir, uint8_t const *src, size_t length) {
  assert(src != nullptr);
  assert(dir != nullptr);
  assert(sizeof(VLDirectoryHeader) <= length);

  std::memcpy(dir, src, sizeof(VLDirectoryHeader));

  if (dir->version != kExpectedDirectoryVersion) {
    return -1;
  }

  if (dir->record_length != kExpectedRecordLength) {
    return -2;
  }

  if (dir->time_format != kExpectedTimeFormat) {
    return -3;
  }

  return sizeof(VLDirectoryHeader);
}

int
VLReadNextDirectoryEntry(
    VLRawDirectoryEntry *entry, uint8_t const *src, size_t length) {
  assert(src != nullptr);
  assert(entry != nullptr);

  if (length < sizeof(VLRawDirectoryEntry)) {
    return -1;
  }

  std::memcpy(entry, src, sizeof(VLRawDirectoryEntry));

  return sizeof(VLRawDirectoryEntry);
}
