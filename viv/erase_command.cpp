// erase_command.cpp - Viiiiva erase commands
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

#include "erase_command.hpp"

#include "endian.hpp"

namespace {

/// Sent from client to Viiiiva to erase a file.
constexpr uint16_t kCommandErase = 0x040b;

/// Sent from Viiiiva to client after an erase command.
constexpr uint16_t kCommandEraseReply = 0x050b;

} // namespace

namespace viv {

EraseCommand::EraseCommand(uint16_t index, OnFinishCallback on_finish) noexcept
    : CommandWithReply(kCommandErase, kCommandEraseReply),
      on_finish_(std::move(on_finish)), index_(index) {}

VLPacket
EraseCommand::MakeCommandPacket() const {
  uint8_t payload[sizeof(uint16_t)];
  VLWriteLittleInt16(payload, 0, index_);
  return VLMakePacket(kVLSeqnoEnd, kCommandErase, payload, sizeof(payload));
}

int
EraseCommand::ReadReply(VLPacket const &packet) {
  if (!has_ack_ || is_finished_) {
    return -1;
  }
  if (OSReadLittleInt16(packet.cmd, 0) != kCommandEraseReply ||
      (packet.payload_length != 1) || (packet.payload[0] != 0) ||
      VLValidatePacketFromViva(&packet)) {
    return -2;
  }

  is_finished_ = true;
  return 0;
}

bool
EraseCommand::MaybeFinish() const {
  return has_ack_ && is_finished_;
}

} // namespace viv
