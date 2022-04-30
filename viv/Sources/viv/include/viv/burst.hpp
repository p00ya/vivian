// burst.hpp - multi-packet transmissions
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

#ifndef viv_burst_hpp
#define viv_burst_hpp

#include <cstdint>
#include <utility>

#include "viv/compat.h"
#include "viv/packet.h"

#pragma clang assume_nonnull begin

namespace viv {

constexpr uint8_t kSeqnoUninitialized = 0;
constexpr uint8_t kSeqnoInvalid = 8;

// Encapsulate state tracking related to burst (multi-packet) transmissions.
// Guaranteed to be an aggregate type and forward-declarable as struct.
struct BurstState {
  /// Next expected sequence number; may also encode error states.
  uint8_t seqno;
};

/// Immutable wrapper for VLBurstState.
class Burst {
public:
  /// Creates a burst with no packets read.
  Burst() : burst_state_{0} {}

  /// Creates a burst from the given burst state.
  explicit Burst(BurstState burst_state) noexcept
      : burst_state_(std::move(burst_state)) {}

  /// Returns true if no packets have been read.
  bool IsEmpty() const { return burst_state_.seqno == kSeqnoUninitialized; }

  /// Returns true if the last packet has already been received.
  bool HasEnded() const { return burst_state_.seqno == kVLSeqnoEnd; }

  bool IsValid() const { return burst_state_.seqno != kSeqnoInvalid; }

  /// Updates the burst with the given packet.
  ///
  /// The updated burst state will have an invalid status if the packet is
  /// out-of-sequence.
  Burst ReadPacket(VLPacket const &packet) const;

  /// Returns the underlying burst state.
  const BurstState &burst_state() const { return burst_state_; }

private:
  /// State of all previous valid packets.
  BurstState burst_state_;
};

} // namespace viv

#pragma clang assume_nonnull end

#endif /* viv_burst_hpp */
