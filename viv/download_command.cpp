// erase_command.cpp - Viiiiva download commands
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

#include "download_command.hpp"

#include <algorithm>
#include <cassert>
#include <cstdlib>
#include <cstring>
#include <iterator>

#include "burst.hpp"
#include "endian.hpp"
#include "packet.h"

namespace {

/// Sent from host to Viiiiva to download a file.
constexpr VLCommandId kCommandDownload = 0x010b;

/// Sent from Viiiiva to host after a download command.
constexpr VLCommandId kCommandDownloadReply = 0x030b;

/// File index for the directory node.
constexpr uint8_t kDirectoryIndex = 0;

/// Number of bytes per directory record.
///
/// While directory requests look like a download request with index 0, the ack
/// is subtly different in that the length field corresponds to the number of
/// records in the response, rather than the number of bytes.
constexpr std::size_t kDirectoryRecordLength = 16;

} // namespace

namespace viv {

DownloadCommand::DownloadCommand(
    uint16_t index, uint32_t offset, uint32_t length,
    OnFinishCallback on_finish) noexcept
    : CommandWithReply(kCommandDownload, kCommandDownloadReply),
      on_finish_(std::move(on_finish)), offset_(offset), length_(length),
      index_(index) {}

VLPacket
DownloadCommand::MakeCommandPacket() const {
  uint8_t payload[sizeof(uint16_t) + sizeof(uint32_t) + sizeof(uint32_t)];
  uint8_t *p = payload;

  p += VLWriteLittleInt16(p, 0, index_);
  p += VLWriteLittleInt32(p, 0, offset_);
  VLWriteLittleInt32(p, 0, length_);

  return VLMakePacket(kVLSeqnoEnd, kCommandDownload, payload, sizeof(payload));
}

int
DownloadCommand::ReadAck(VLPacket const &packet) {
  int const err = ::viv::ReadAck(packet, kCommandDownload);
  if (err) {
    return err;
  }
  uint32_t const length = OSReadLittleInt32(packet.payload, 6);
  if ((index_ != OSReadLittleInt16(packet.payload, 0)) ||
      (offset_ != OSReadLittleInt32(packet.payload, 2)) || (length > length_)) {
    return -3;
  }
  if (index_ == kDirectoryIndex) {
    buf_.reserve(length * kDirectoryRecordLength);
  } else {
    buf_.reserve(length);
  }
  has_ack_ = true;
  return 0;
}

int
DownloadCommand::ReadReply(VLPacket const &packet) {
  if (OSReadLittleInt16(packet.cmd, 0) != kCommandDownloadReply ||
      (packet.payload_length == 0) || VLValidatePacketFromViva(&packet)) {
    return -1;
  }

  auto const burst = burst_.ReadPacket(packet);
  if (!burst.IsValid()) {
    return -2;
  }
  burst_ = std::move(burst);

  std::copy(
      packet.payload, packet.payload + packet.payload_length,
      std::back_inserter(buf_));

  return packet.payload_length;
}

bool
DownloadCommand::MaybeFinish() const {
  if (has_ack_ && burst_.HasEnded()) {
    on_finish_(index_, buffer(), length());
    return true;
  }
  return false;
}

} // namespace viv
