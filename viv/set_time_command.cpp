// set_time_command.cpp - Viiiiva set time command
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

#include "set_time_command.hpp"

#include "endian.hpp"

namespace {

/// Sent from host to Viiiiva to set its time.
constexpr uint16_t kCommandSetTime = 0x0108;

} // namespace

namespace viv {

VLPacket
SetTimeCommand::MakeCommandPacket() const {
  uint8_t payload[sizeof(uint32_t)];

  OSWriteLittleInt32(payload, 0, time_);
  return VLMakePacket(kVLSeqnoEnd, kCommandSetTime, payload, sizeof(payload));
}

int
SetTimeCommand::ReadPacket(VLPacket const &packet) {
  int const err = ::viv::ReadAck(packet, kCommandSetTime);
  if (err == 0) {
    has_ack_ = true;
  }
  return err;
}

bool
SetTimeCommand::MaybeFinish() const {
  on_finish_(has_ack_);

  return has_ack_;
}

} // namespace viv
