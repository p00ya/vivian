// erase_command.hpp - Viiiiva erase commands
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

#ifndef viv_erase_command_hpp
#define viv_erase_command_hpp

#include <cstdint>
#include <functional>

#include "viv/command.hpp"
#include "viv/compat.h"
#include "viv/packet.h"

#pragma clang assume_nonnull begin

namespace viv {

/// Command for downloading a file (or the directory itself).
class EraseCommand : public CommandWithReply {
public:
  /// Function to call once the file has been erased.
  ///
  /// The boolean parameter is true if the erase was successful, false
  /// otherwise.
  using OnFinishCallback = ::std::function<void(bool)>;

  explicit EraseCommand(uint16_t index, OnFinishCallback on_finish) noexcept;

  VLPacket MakeCommandPacket() const override;

  bool MaybeFinish() const override;
  bool ShouldAckReply() const override { return true; }

  ::std::string name() const override { return "erase command"; }

protected:
  int ReadReply(VLPacket const &packet) override;

private:
  OnFinishCallback const on_finish_;
  uint16_t const index_;
  bool is_ok_ = false;
  bool is_finished_ = false;
};

} // namespace viv

#pragma clang assume_nonnull end

#endif /* viv_erase_command_hpp */
