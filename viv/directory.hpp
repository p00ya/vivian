// directory.hpp - directory and file utilities
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

#ifndef viv_directory_hpp
#define viv_directory_hpp

#include <cstdint>
#include <cstdlib>
#include <ctime>
#include <map>
#include <utility>

#include "compat.h"
#include "directory_entry.h"
#include "endian.hpp"
#include "raw_directory.h"
#include "time.h"

#pragma clang assume_nonnull begin

namespace viv {

/// Bit-flags for VLRawDirectoryEntry::flags.
enum [[clang::flag_enum]] FileFlags : uint8_t{
    // Miscellaneous file.
    //
    // Observed on a Viiiiva, but with unknown semantics.
    kUnknown = 0x10,

    // File may be erased.
    kErasable = 0x20,

    // File can be downloaded.
    kReadable = 0x40,
};

/// Immutable wrapper for reading a directory entry.
class DirectoryEntry {
public:
  explicit DirectoryEntry(VLRawDirectoryEntry entry) noexcept
      : entry_(::std::move(entry)) {}

  /// Returns the type of the file.
  VLFileType file_type() const {
    uint16_t file_type = entry_.file_type | (entry_.subtype << 8);
    return static_cast<VLFileType>(file_type);
  }

  /// Returns the file index in host byte-order.
  uint16_t index() const { return OSReadLittleInt16(entry_.index, 0); }

  /// Returns the file length in host byte-order.
  uint32_t length() const { return OSReadLittleInt32(entry_.length, 0); }

  /// Returns the POSIX timestamp of the file.
  time_t time() const {
    return VLGetPosixTimeFromViva(OSReadLittleInt32(entry_.time, 0));
  }

  /// Returns the logical directory entry.
  VLDirectoryEntry entry() const {
    return VLDirectoryEntry{time(), length(), index(), file_type()};
  }

  /// Returns the underlying directory entry.
  VLRawDirectoryEntry const &raw_entry() const { return entry_; }

private:
  VLRawDirectoryEntry const entry_;
};

/// Encapsulates the entries of a directory.
class Directory {
public:
  class Reader;

  explicit Directory(
      VLDirectoryHeader header,
      ::std::map<uint16_t, DirectoryEntry> entries) noexcept
      : header_(::std::move(header)), entries_(::std::move(entries)) {}

  const VLDirectoryHeader &header() const { return header_; }

  const ::std::map<uint16_t, DirectoryEntry> &entries() const {
    return entries_;
  }

private:
  VLDirectoryHeader header_;
  ::std::map<uint16_t, DirectoryEntry> entries_;
};

/// Reads a directory response from a buffer.
class Directory::Reader {
public:
  explicit Reader(uint8_t const *src, size_t length) noexcept;

  /// Reads the buffer.
  ///
  /// \return Whether the directory was read successfully.
  bool Read();

  /// Returns a directory wrapper, invalidating this object.
  ///
  /// Should only be called if \c Read() returned true.
  Directory get() const;

private:
  ::std::map<uint16_t, DirectoryEntry> entries_;
  VLDirectoryHeader hdr_;
  uint8_t const *src_;
  uint8_t const *const end_;
  bool valid_;
};

} // namespace viv

#pragma clang assume_nonnull end

#endif /* viv_directory_hpp */
