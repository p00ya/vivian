// set_time_command.hpp - Viiiiva set time command
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

#ifndef viv_set_time_command_hpp
#define viv_set_time_command_hpp

#include <cstdint>

#include "viv/command.hpp"
#include "viv/compat.h"
#include "viv/packet.h"

#pragma clang assume_nonnull begin

namespace viv {

/// Command for downloading a file.
class SetTimeCommand : public Command {
public:
  /// Function to call once the file has been erased.
  ///
  /// The boolean parameter is true if the erase was successful, false
  /// otherwise.
  using OnFinishCallback = ::std::function<void(bool)>;

  explicit SetTimeCommand(uint32_t ant_time, OnFinishCallback on_finish)
    noexcept : on_finish_(std::move(on_finish)), time_(ant_time) {}

  VLPacket MakeCommandPacket() const override;
  int ReadPacket(VLPacket const &packet) override;
  bool MaybeFinish() const override;

  ::std::string name() const override { return "set time command"; }

private:
  OnFinishCallback const on_finish_;

  /// ANT+ time to send to Viiiiva.
  uint32_t const time_;

  /// True once the acknowledgement is received.
  bool has_ack_ = false;
};

} // namespace viv

#pragma clang assume_nonnull end

#endif /* viv_set_time_command_hpp */
