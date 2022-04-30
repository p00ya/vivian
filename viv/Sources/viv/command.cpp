// command.cpp - description
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

#include "viv/command.hpp"

#include "viv/endian.hpp"

namespace viv {

int
ReadAck(VLPacket const &packet, VLCommandId cmd) {
  int const err = VLValidatePacketFromViva(&packet);
  if (err) {
    return err;
  }
  if (OSReadLittleInt16(packet.cmd, 0) != AcknowledgementForCommand(cmd)) {
    return -2;
  }
  return 0;
}

int
CommandWithReply::ReadAck(VLPacket const &packet) {
  int const err = ::viv::ReadAck(packet, cmd_);
  if (err == 0) {
    has_ack_ = true;
  }
  return err;
}

} // namespace viv
