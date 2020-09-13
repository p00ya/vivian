// command.hpp - Command abstraction
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

#ifndef viv_command_hpp
#define viv_command_hpp

#include <cstdint>
#include <string>

#include "packet.h"

namespace viv {

/// Pure virtual interface for a command sent to a Viiiiva.
class Command {
public:
  explicit Command() noexcept {}

  // Disallow copy/move semantics.
  Command(const Command &) = delete;
  Command &operator=(const Command &) = delete;

  virtual ~Command() = default;

  /// Creates a write packet for sending to Viiiiva.
  virtual VLPacket MakeCommandPacket() const = 0;

  /// Returns a name for the command (for error messages etc.).
  virtual ::std::string name() const = 0;

  /// Read a GATT value notification packet.
  ///
  /// Commands will trigger value notifications from the Viiiiva, such as
  /// acknowledgement packets and commands sent from the Viiiiva itself.
  ///
  /// \return 0 for packets that were expected for this command.
  virtual int ReadPacket(const VLPacket &packet) = 0;

  /// Checks if the command is finished, and trigger any callbacks.
  ///
  /// The command is finished if it is not expecting to read more packets (e.g.
  /// a GATT write response or GATT value notifications), or if it is in an
  /// error state.
  ///
  /// \return True unless the command is still expecting a response.
  virtual bool MaybeFinish() const = 0;
};

/// Skeleton implementation for a command that expects both an acknowledgement
/// and an additional "reply" command sent from the Viiiiva.
class CommandWithReply : public Command {
public:
  CommandWithReply(VLCommandId cmd, VLCommandId reply_cmd)
      : cmd_(cmd), reply_cmd_(reply_cmd) {}

  ~CommandWithReply() override = default;

  int ReadPacket(const VLPacket &packet) override {
    return has_ack_ ? ReadReply(packet) : ReadAck(packet);
  }

  /// Returns true unless more response packets are expected.
  virtual bool MaybeFinish() const override = 0;

  /// Returns true if reply packets should be acknowledged.
  virtual bool ShouldAckReply() const { return false; }

  /// Returns a suitable packet for acknowledging the reply.
  VLPacket MakeResponseAckPacket() const { return VLMakeAckPacket(reply_cmd_); }

protected:
  /// Validates an acknowledgement packet.
  ///
  /// Note this is separate from the GATT "write response" - it is an
  /// additional value notification sent after the write response.
  virtual int ReadAck(VLPacket const &packet);

  /// Validates a reply command sent from the Viiiiva.
  virtual int ReadReply(VLPacket const &packet) = 0;

  VLCommandId const cmd_;
  VLCommandId const reply_cmd_;
  bool has_ack_ = false;
};

/// Returns the command for a response to \p cmd.
inline VLCommandId
AcknowledgementForCommand(VLCommandId cmd) {
  return cmd | 0x8000;
}

/// Validates an acknowledgement packet.
///
/// Note this is separate from the GATT "write response" - it is an
/// additional value notification sent after the write response.
///
/// \return 0 if the packet had the correct direction and command set.
int ReadAck(VLPacket const &packet, VLCommandId cmd);

} // namespace viv

#endif /* viv_command_hpp */
