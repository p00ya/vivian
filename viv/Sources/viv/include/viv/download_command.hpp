// download_command.hpp - Viiiiva download commands
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

#ifndef viv_download_command_hpp
#define viv_download_command_hpp

#include <cstdint>
#include <functional>
#include <utility>
#include <vector>

#include "viv/burst.hpp"
#include "viv/command.hpp"
#include "viv/compat.h"
#include "viv/packet.h"

#pragma clang assume_nonnull begin

namespace viv {

/// Command for downloading a file (or the directory itself).
///
/// Accumulates the file content from ReadResponse calls.
class DownloadCommand : public CommandWithReply {
public:
  /// Function to call once the file has been downloaded.  It is called with
  /// the file index, file contents, and file length respectively.
  using OnFinishCallback =
      ::std::function<void(uint16_t, uint8_t const *, size_t)>;

  /// Convenience constructor for a download at offset 0 and no length limit.
  DownloadCommand(uint16_t index, OnFinishCallback on_finish) noexcept
      : DownloadCommand(index, 0, 0xffffffffUL, ::std::move(on_finish)) {}

  /// Creates a download command for reading a particular file.
  ///
  /// \param index The file (ANT-FS index) to download (host byte order).
  /// \param offset Byte offset within file to start download from (host byte
  /// order).
  /// \param length Maximum length of the file in bytes (host byte order).
  DownloadCommand(
      uint16_t index, uint32_t offset, uint32_t length,
      OnFinishCallback const on_finish) noexcept;

  VLPacket MakeCommandPacket() const override;

  /// Returns true after the full file has been read, or there was an error.
  bool MaybeFinish() const override;

  /// The contents of the file read so far.
  ///
  /// Only up to \c length() bytes should be read from the returned buffer.
  uint8_t const *buffer() const { return buf_.data(); }

  /// The number of bytes of the file read so far.
  size_t length() const { return buf_.size(); }

  ::std::string name() const override { return "download command"; }

protected:
  /// Reads the first response packet.
  int ReadAck(VLPacket const &packet) override;

  /// Appends the file contents from \p packet to the file buffer.
  ///
  /// \param packet The packet to read.
  ///
  /// \return The number of bytes copied, or negative if the packet is not valid
  /// as the next packet in a download response burst.
  int ReadReply(VLPacket const &packet) override;

private:
  /// Contents of the file.
  ::std::vector<uint8_t> buf_;

  OnFinishCallback const on_finish_;

  /// State tracking for the response burst.
  Burst burst_;

  // Initial request parameters.
  uint32_t const offset_;
  uint32_t const length_;
  uint16_t const index_;
};

} // namespace viv

#pragma clang assume_nonnull end

#endif /* viv_download_command_hpp */
