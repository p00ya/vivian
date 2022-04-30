// packet.h - Viiiiva config packets
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

#ifndef viv_packet_h
#define viv_packet_h

#ifdef __cplusplus
#include <cstdint>
#include <cstdlib>
#else
#include <stdint.h>
#include <stdlib.h>
#endif

#include "viv/compat.h"

#ifdef __clang__
#pragma clang assume_nonnull begin
#endif

// Sequence number for the final packet in a burst.
#ifdef __cplusplus
constexpr uint8_t kVLSeqnoStart = 0;
constexpr uint8_t kVLSeqnoEnd = 7;
#else
#define kVLSeqnoStart ((uint8_t)0)
#define kVLSeqnoEnd ((uint8_t)7)
#endif

// Maximum length in bytes of a Viiiiva config packet.
enum { kVLPacketMaxLength = 20 };

/// One Viiiiva protocol packet.
///
/// These packets are embedded as values in BLE GATT characteristics.
/// Use the VLPacket family of functions for access.
///
/// This struct is intended to be used for type-punning a single packet buffer.
/// It must be packed and POD.
struct __attribute__((packed)) VLPacket {
  /// The sequence number + CRC.
  uint8_t crc;

  /// Length of the payload.  Note that this is not the same as the length
  /// of the packet.
  uint8_t payload_length;

  /// Identifies the sender of the packet.
  uint8_t sender;

  /// Identifies the receiver of the packet.
  uint8_t receiver;

  /// Identifies the type of command this packet corresponds to, and whether
  /// it is an acknowledgement or the command itself.
  uint8_t cmd[2];

  /// Buffer for the payload; only \c payload_length bytes are meaningful.
  uint8_t payload[14];
};
typedef struct VLPacket VLPacket;

/// Corresponds to VLPacket::cmd, interpreted as a little-endian integer.
typedef uint16_t VLCommandId;

#ifdef __cplusplus
extern "C" {
#endif

// clang-format breaks the CF_SWIFT_NAME selectors.
// clang-format off

/// Returns the length of \p packet.
///
/// This is the length of the entire GATT characteristic value, rather than
/// the length of the payload contained within the packet.
extern size_t VLPacketLength(VLPacket const *packet)
    CF_SWIFT_NAME(getter:VLPacket.length(self:));

/// Returns the sequence number for \p packet.
extern uint8_t VLPacketSeqno(VLPacket const *packet)
    CF_SWIFT_NAME(getter:VLPacket.seqno(self:));

// clang-format on

/// Returns the next non-terminal sequence number after \p seqno.
extern uint8_t VLGetNextSeqno(uint8_t seqno);

/// Returns non-zero if `seqno == expected`, or if seqno marks the end of a
/// burst.
extern int VLDoesSeqnoMatch(uint8_t seqno, uint8_t expected);

/// Reads a packet with \p length bytes from \p src, into \p packet.
/// \return Non-zero if the packet was invalid (bad CRC or length).
extern int VLReadPacket(VLPacket *packet, uint8_t const *src, size_t length);

/// Returns non-zero if \p packet is not marked as coming from Viiiiva.
extern int VLValidatePacketFromViva(const VLPacket *packet);

/// Creates a packet for sending to the Viiiiva.
///
/// This function populates the CRC.  The resulting packet's length is
/// \p payload_length + 6.
///
/// \param seqno Sequence number (from kVLSeqnoStart to kVLSeqnoEnd inclusive).
/// \param cmd Command ID (host byte-order).
/// \param payload Payload to encapsulate in the packet.
/// \param payload_length Number of bytes to read from |payload|; at most 14.
extern VLPacket VLMakePacket(
    uint8_t seqno, VLCommandId cmd, uint8_t const *_Nullable payload,
    size_t payload_length);

/// Creates an outgoing packet to acknowledge \p cmd.
extern VLPacket VLMakeAckPacket(VLCommandId cmd);

/// Write the network representation of \p packet to \p dst.  The memory regions
/// defined by the two parameters must not overlap.
extern void VLWritePacket(uint8_t *dst, VLPacket const *packet);

#ifdef __cplusplus
} // extern "C"
#endif

#ifdef __clang__
#pragma clang assume_nonnull end
#endif

#endif /* viv_packet_h */
