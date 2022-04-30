// burst.cpp - multi-packet transmissions
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

#include "viv/burst.hpp"

#include <cstdint>

#include "viv/packet.h"

namespace viv {

Burst
Burst::ReadPacket(VLPacket const &packet) const {
  uint8_t const seqno = VLPacketSeqno(&packet);
  if (!VLDoesSeqnoMatch(seqno, burst_state_.seqno) ||
      burst_state_.seqno == kVLSeqnoEnd) {
    return Burst(BurstState{kSeqnoInvalid});
  } else if (seqno == kVLSeqnoEnd) {
    return Burst(BurstState{seqno});
  }

  return Burst(BurstState{VLGetNextSeqno(seqno)});
}

} // namespace viv
