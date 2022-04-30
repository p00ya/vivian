// raw_directory.h - raw directory structures
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

#ifndef viv_raw_directory_h
#define viv_raw_directory_h

#ifdef __cplusplus
#include <cstdint>
#include <cstdlib>
#else
#include <stdint.h>
#include <stdlib.h>
#endif

#include "viv/compat.h"

#ifdef __clang__
#pragma clang assume_nonnull begin
#endif

/// ANT-FS style directory header.
///
/// This struct is intended for type-punning.  It must be packed and POD.
struct __attribute__((packed)) VLRawDirectoryHeader {
  /// Directory header version.
  uint8_t version;

  /// Length of each directory entry.
  uint8_t record_length;

  /// Always 1 (times are seconds since 1989-12-31 UTC).
  uint8_t time_format;

  /// Always 0.
  uint8_t reserved_3_[5];

  /// Current time (little-endian seconds since 1989-12-31 UTC).
  uint8_t time[4];

  /// Always 0 for Viiiiva.
  uint8_t reserved_8_[4];
};
typedef struct VLRawDirectoryHeader VLDirectoryHeader;

/// ANT-FS style directory entry.
///
/// This struct is intended for type-punning.  It must be packed and POD.
struct __attribute__((packed)) VLRawDirectoryEntry {
  /// Little-endian index for this file.
  uint8_t index[2];

  /// ANT-FS file type.
  uint8_t file_type;

  /// Sub-type of the file type.
  uint8_t subtype;

  /// Little-endian file ID.
  ///
  /// This field depends on the file type, but for practical purposes, on the
  /// Viiiiva it is identical to index.
  uint8_t file_id[2];

  /// Type flags (semantics defined by file_type).
  uint8_t type_flags;

  /// File operation flags.
  uint8_t flags;

  /// Little-endian size of file in bytes.
  uint8_t length[4];

  /// File timestamp (little-endian seconds since 1989-12-31 UTC).
  uint8_t time[4];
};
typedef struct VLRawDirectoryEntry VLRawDirectoryEntry;

#ifdef __cplusplus
extern "C" {
#endif

/// Reads a directory header from \p src.
///
/// \param src The source buffer to read the directory header from.
/// \param length The size of the buffer, should be at least as big as
/// a directory header.
/// \param[out] dir Directory header to write into.
///
/// \return The number of bytes read, or negative if there was an error.
extern int VLReadDirectoryHeader(
    VLDirectoryHeader *dir, uint8_t const *src, size_t length);

/// Reads a directory entry from \p src.
///
/// \param src The source buffer to read the directory entry from.
/// \param length The size of the buffer, should be at least as big as
/// one directory entry.
/// \param[out] entry Directory entry to write into.
///
/// \return The number of bytes read, or negative if there was an error.
extern int VLReadNextDirectoryEntry(
    VLRawDirectoryEntry *entry, uint8_t const *src, size_t length);

#ifdef __cplusplus
} // extern "C"
#endif

#ifdef __clang__
#pragma clang assume_nonnull end
#endif

#endif /* viv_raw_directory_h */
