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

#include "viv/directory.hpp"

#include <cassert>
#include <cstdint>
#include <cstdlib>
#include <utility>

#include "viv/directory_entry.h"
#include "viv/raw_directory.h"

namespace viv {

Directory::Reader::Reader(uint8_t const *src, size_t length) noexcept
    : entries_(), src_(src), end_(src_ + length), valid_() {
  assert(src != nullptr);
  assert(src <= end_);
}

bool
Directory::Reader::Read() {
  entries_.clear();

  int read = VLReadDirectoryHeader(&hdr_, src_, end_ - src_);
  if (read < 0) {
    return false;
  }

  for (auto *p = src_ + read; p < end_; p += read) {
    VLRawDirectoryEntry raw;
    read = VLReadNextDirectoryEntry(&raw, p, end_ - p);
    if (read < 0) {
      return false;
    }

    DirectoryEntry entry(std::move(raw));
    entries_.emplace(entry.index(), std::move(entry));
  }

  valid_ = true;
  return true;
}

Directory
Directory::Reader::get() const {
  return Directory(std::move(hdr_), std::move(entries_));
}

} // namespace viv
