// directory_entry.h - logical directory entry
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

#ifndef viv_directory_entry_h
#define viv_directory_entry_h

#ifdef __cplusplus
#include <cstdint>
#include <cstdlib>
#include <ctime>
#else
#include <stdint.h>
#include <stdlib.h>
#include <time.h>
#endif

#include "compat.h"

/// The type of a file.
///
/// This combines what ANT-FS would call the type and sub-type.
VL_ENUM(uint16_t, VLFileType){
    /// Unknown file type observed on real device.
    kVLFileTypeUnknown0001 = 0x0001,

    /// Unknown file type observed on real device.
    kVLFileTypeFitDevice = 0x0180,

    /// .FIT Activity file.
    kVLFileTypeFitActivity = 0x0480,
};
typedef enum VLFileType VLFileType;

// Logical content of a directory entry.
//
// This is a high-level interface and does not directly correspond to the
// network format.
struct VLDirectoryEntry {
  /// Creation time of the file, in seconds since POSIX epoch.
  time_t posix_time;

  /// Length of the file in bytes.
  uint32_t length;

  /// Identifier of the file for commands.
  uint16_t index;

  /// Type of the file.
  VLFileType file_type;
};
typedef struct VLDirectoryEntry VLDirectoryEntry;

#endif /* viv_directory_entry_h */
