// manager.hpp
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

#ifndef viv_manager_hpp
#define viv_manager_hpp

#include <cassert>
#include <cstdint>
#include <cstdlib>
#include <ctime>
#include <memory>
#include <string>

#include "command.hpp"
#include "compat.h"
#include "directory_entry.h"
#include "manager_error_code.h"

#pragma clang assume_nonnull begin

namespace viv {

/// Delegate pattern for callbacks from Manager to client code.
class ManagerDelegate {
public:
  ManagerDelegate() = default;

  // Disable implicit copy/move.
  ManagerDelegate(const ManagerDelegate &) = delete;
  ManagerDelegate &operator=(const ManagerDelegate &) = delete;

  virtual ~ManagerDelegate() noexcept = default;

  virtual int WriteValue(uint8_t const *value, size_t length) = 0;

  virtual void DidStartWaiting() const = 0;

  virtual void DidFinishWaiting() const = 0;

  virtual void
  DidError(VLManagerErrorCode code, ::std::string const &&msg) const = 0;

  virtual void DidParseDirectoryEntry(VLDirectoryEntry entry) const {}

  virtual void DidFinishParsingDirectory() const {}

  virtual void
  DidDownloadFile(uint16_t index, uint8_t const *data, size_t length) const {}

  virtual void DidEraseFile(uint16_t index, bool ok) const {}
};

class Manager {
public:
  /// Initialize a manager to call functions on \p delegate, assuming ownership.
  explicit Manager(::std::unique_ptr<ManagerDelegate> delegate) noexcept
      : delegate_(::std::move(delegate)), busy_(false) {}

  void NotifyValue(uint8_t const *value, size_t length);

  void NotifyTimeout();

  void DownloadDirectory();

  void DownloadFile(uint16_t index);

  void EraseFile(uint16_t index);

  void SetTime(time_t posix_time);

private:
  void WritePacket(VLPacket const &packet) {
    WritePacket(packet, true);
  }

  /// Serializes the packet and sends it to the delegate.
  void WritePacket(VLPacket const &packet, bool wait_for_ack);

  ::std::unique_ptr<ManagerDelegate> const delegate_;

  /// The in-progress command.  Null if there is no command in progress, or the
  /// command has a response.
  ::std::unique_ptr<Command> command_;

  /// The in-progress command (if it has a reply), or null.
  ::std::unique_ptr<CommandWithReply> response_;

  /// True if a function on this manager is already executing.  This can detect
  /// logic errors in delegate methods that recurse back into the manager.
  /// Only used if NDEBUG is not defined.
  bool busy_;
};

} // namespace viv

#pragma clang assume_nonnull end

#endif /* viv_manager_hpp */
