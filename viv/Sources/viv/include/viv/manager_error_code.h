// manager_error_code.h - error codes for the manager
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

#ifndef manager_error_code_h
#define manager_error_code_h

#include "viv/compat.h"

/// Error codes returned by the manager class and its bridges.
VL_ENUM(int, VLManagerErrorCode){
    /// There was no error.
    kVLManagerErrorNone = 0,

    /// The header part of the packet (sequence number, length, CRC) was
    /// invalid.
    kVLManagerErrorBadHeader = 1,

    /// The payload part of the pacet was invalid.
    kVLManagerErrorBadPayload = 2,

    /// Notification of a GATT value (WriteResponse or Notification) wasn't
    /// expected at this time, or the manager was notified of a timeout when
    /// it was expecting a value.
    kVLManagerErrorUnexpected = 3,
};
typedef enum VLManagerErrorCode VLManagerErrorCode;

#endif /* manager_error_code_h */
