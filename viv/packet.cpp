// packet.cpp - Viiiiva config packets
// Copyright Dean Scarff
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

#include "packet.h"

#include <cassert>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <type_traits>

#include "crc.hpp"
#include "endian.hpp"

namespace {

/// Byte offsets within the characteristic value / VLPacket struct.
constexpr size_t kPacketOffsetLength = 1;
constexpr size_t kPacketOffsetPayload = 6;
constexpr size_t kPacketMinLength = 6;
constexpr size_t kPacketMaxLength = 20;

/// Value in the third byte of packets from host to Viiiiva, or the fourth
/// byte of packets from Viiiiva to host.
constexpr uint8_t kPeerHost = 3;

/// Value in the third byte of packets from Viiiiva to host, or the fourth byte
/// of packets from host to Viiiiva.
constexpr uint8_t kPeerViiiiva = 1;

/// The maximum non-terminal sequence number before the sequence number wraps
/// back to 1.
constexpr uint8_t kSeqnoModulus = 6;

// This implementation assumes there is no padding between the members of
// VLPacket.  Since all the fields are uint8_t (or arrays thereof), most
// compilers can be convinced to forgo any padding.
static_assert(
    sizeof(VLPacket) == 20,
    "VLPacket must be packed; coax the compiler to pack it");

static_assert(
    std::is_pod<VLPacket>::value, "VLPacket must be POD; check its definition");

} // namespace

size_t
VLPacketLength(VLPacket const *packet) {
  assert(packet != nullptr);

  return packet->payload_length + kPacketOffsetPayload;
}

uint8_t
VLPacketSeqno(VLPacket const *packet) {
  assert(packet != nullptr);

  return packet->crc >> 5;
}

uint8_t
VLGetNextSeqno(uint8_t seqno) {
  return (seqno % kSeqnoModulus) + 1;
}

int
VLDoesSeqnoMatch(const uint8_t seqno, uint8_t expected) {
  return seqno == expected || seqno == kVLSeqnoEnd;
}

VLPacket
VLMakePacket(
    uint8_t seqno, uint16_t cmd, uint8_t const *_Nullable payload,
    size_t payload_length) {
  assert(seqno <= 7);
  assert(payload_length == 0 || payload != nullptr);
  assert(
      (payload_length < kVLPacketMaxLength) && /* in case of overflow */
      (payload_length + kPacketOffsetPayload <= kVLPacketMaxLength));

  VLPacket packet = {0};
  packet.payload_length = static_cast<uint8_t>(payload_length);
  packet.sender = kPeerHost;
  packet.receiver = kPeerViiiiva;

  VLWriteLittleInt16(packet.cmd, 0, cmd);
  std::memcpy(packet.payload, payload, payload_length);
  // 3-bit sequence number and 5-bit masked-CRC are packed into one byte.
  seqno <<= 5;

  // This code relies on the compiler correctly packing the VLPacket struct:
  // it provides read access to the command and payload via a pointer to
  // payload_length.
  seqno |=
      0x1f & viv::crc(
                 &packet.payload_length,
                 payload_length + kPacketOffsetPayload - kPacketOffsetLength);
  packet.crc = seqno;
  return packet;
}

VLPacket
VLMakeAckPacket(VLCommandId cmd) {
  return VLMakePacket(kVLSeqnoEnd, cmd | 0x8000U, nullptr, 0);
}

void
VLWritePacket(uint8_t *dst, VLPacket const *packet) {
  assert(dst != nullptr);
  assert(packet != nullptr);

  // VLPacket's packed, POD layout allows this direct copy:
  std::memcpy(dst, packet, kPacketOffsetPayload + packet->payload_length);
}

int
VLReadPacket(VLPacket *packet, uint8_t const *src, size_t length) {
  assert(packet != nullptr);
  assert(src != nullptr);

  if (length > kPacketMaxLength || length < kPacketMinLength ||
      length != kPacketOffsetPayload + src[kPacketOffsetLength]) {
    return -1;
  }
  std::memcpy(packet, src, length);

  if ((0x1f & packet->crc) !=
      (0x1f &
       viv::crc(&packet->payload_length, length - kPacketOffsetLength))) {
    return -2;
  }

  return 0;
}

int
VLValidatePacketFromViva(VLPacket const *packet) {
  assert(packet != nullptr);

  return packet->sender != kPeerViiiiva || packet->receiver != kPeerHost;
}
