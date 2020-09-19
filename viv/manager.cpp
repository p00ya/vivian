// viv_manager.cpp
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

#include "manager.hpp"

#include <cassert>
#include <cstdint>
#include <cstdlib>
#include <ctime>
#include <memory>
#include <string>
#include <tuple>
#include <type_traits>
#include <utility>

#include "command.hpp"
#include "directory.hpp"
#include "download_command.hpp"
#include "erase_command.hpp"
#include "packet.h"
#include "raw_directory.h"
#include "set_time_command.hpp"
#include "time.h"

#pragma clang assume_nonnull begin

namespace {

/// Cheap scoped assertion for mutual exclusion.
///
/// This only protects against recursion from within one thread, it does not
/// robustly detect multi-threaded concurrency.  If DEBUG is not true, then
/// it does nothing at all.
class AssertNoRecursion {
public:
  explicit AssertNoRecursion(bool &busy) : busy_(busy) {
    if (DEBUG) {
      assert(!busy);
      busy = true;
    }
  }

  AssertNoRecursion() = delete;
  AssertNoRecursion(const AssertNoRecursion &) = delete;
  AssertNoRecursion &operator=(const AssertNoRecursion &) = delete;

  ~AssertNoRecursion() {
    if (DEBUG) {
      busy_ = false;
    }
  }

private:
  bool &busy_;
};

} // namespace

namespace viv {

void
Manager::NotifyValue(uint8_t const *value, size_t length) {
  AssertNoRecursion busy(busy_);

  if (!command_ && !response_) {
    delegate_->DidError(
        kVLManagerErrorUnexpected, "Unexpected value notification");
    return;
  }
  Command &command = (response_) ? *response_ : *command_;

  VLPacket packet;
  if (VLReadPacket(&packet, value, length)) {
    delegate_->DidError(
        kVLManagerErrorBadHeader,
        command.name() + ": invalid value notification");
    return;
  }

  if (command.ReadPacket(packet) < 0) {
    delegate_->DidError(
        kVLManagerErrorBadPayload,
        command.name() + ": invalid value notification");
    return;
  }

  if (command.MaybeFinish()) {
    delegate_->DidFinishWaiting();
    if (response_ && response_->ShouldAckReply()) {
      const VLPacket packet = response_->MakeResponseAckPacket();
      WritePacket(packet, false);
    }
    response_.release();
  }
}

void
Manager::NotifyTimeout() {
  AssertNoRecursion busy(busy_);
  if (command_) {
    delegate_->DidError(
        kVLManagerErrorUnexpected,
        command_->name() + ": timeout waiting for command");
    command_.reset();
    delegate_->DidFinishWaiting();
  }
}

void
Manager::DownloadDirectory() {
  AssertNoRecursion busy(busy_);
  command_.release();
  // While this leaks delegate_ out of its unique_ptr, the response_ is owned by
  // the Manager so will not outlive the delegate.
  auto on_finish = [&delegate = *delegate_](
                       uint16_t index, uint8_t const *data, size_t length) {
    auto reader = Directory::Reader(data, length);
    if (!reader.Read()) {
      delegate.DidError(kVLManagerErrorBadHeader, "Error parsing directory");
      return;
    }
    Directory dir = reader.get();
    for (const auto &pair : dir.entries()) {
      delegate.DidParseDirectoryEntry(pair.second.entry());
    }
    delegate.DidFinishParsingDirectory();
  };
  response_.reset(new DownloadCommand(0, std::move(on_finish)));

  VLPacket packet = response_->MakeCommandPacket();
  WritePacket(packet);
}

void
Manager::DownloadFile(uint16_t index) {
  AssertNoRecursion busy(busy_);
  command_.release();
  // While this leaks delegate_ out of its unique_ptr, the response_ is owned by
  // the Manager so will not outlive the delegate.
  auto on_finish = [&delegate = *delegate_](
                       uint16_t index, uint8_t const *data, size_t length) {
    delegate.DidDownloadFile(index, data, length);
  };
  response_.reset(new DownloadCommand(index, std::move(on_finish)));

  VLPacket packet = response_->MakeCommandPacket();
  WritePacket(packet);
}

void
Manager::EraseFile(uint16_t index) {
  AssertNoRecursion busy(busy_);
  command_.release();
  // While this leaks delegate_ out of its unique_ptr, the response_ is owned by
  // the Manager so will not outlive the delegate.
  auto on_finish = [&delegate = *delegate_, index](bool success) {
    delegate.DidEraseFile(index, success);
  };
  response_.reset(new EraseCommand(index, std::move(on_finish)));

  VLPacket packet = response_->MakeCommandPacket();
  WritePacket(packet);
}

void
Manager::SetTime(time_t posix_time) {
  AssertNoRecursion busy(busy_);
  uint32_t viva_time = VLGetVivaTimeFromPosix(posix_time);
  response_.release();
  command_.reset(new SetTimeCommand(viva_time));

  VLPacket packet = command_->MakeCommandPacket();
  WritePacket(packet);
}

void
Manager::WritePacket(VLPacket const &packet, bool wait_for_ack) {
  // C++17 s[basic.lval] clause 8.8 specifies special aliasing rules for
  // unsigned char, but not uint8_t.  We rely on the (ubiquitous) assumption
  // that they're the same.
  static_assert(
      std::is_same<uint8_t, unsigned char>::value,
      "uint8_t aliases may not be valid");
  uint8_t const *value = reinterpret_cast<uint8_t const *>(&packet);
  if (delegate_->WriteValue(value, VLPacketLength(&packet)) < 0) {
    delegate_->DidError(kVLManagerErrorUnexpected, "WriteValue");
    return;
  }
  if (wait_for_ack) {
    delegate_->DidStartWaiting();
  }
}

} // namespace viv

#pragma clang assume_nonnull end
