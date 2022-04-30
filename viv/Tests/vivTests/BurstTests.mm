// BurstTests.mm - unit tests for viva/burst.hpp
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

#import <XCTest/XCTest.h>

#include "viv/burst.hpp"

@interface BurstTests : XCTestCase

@end

@implementation BurstTests

- (void)testInit {
  viv::Burst burst;
  XCTAssertTrue(burst.IsEmpty());
  XCTAssertFalse(burst.HasEnded());
}

- (void)testIncrement {
  VLPacket packet;
  packet.crc = 0x00;

  viv::Burst burst = viv::Burst().ReadPacket(packet);
  XCTAssertEqual(burst.burst_state().seqno, 1);

  packet.crc = 0x20;
  burst = burst.ReadPacket(packet);
  XCTAssertEqual(burst.burst_state().seqno, 2);

  packet.crc = 0x40;
  burst = burst.ReadPacket(packet);
  XCTAssertEqual(burst.burst_state().seqno, 3);

  packet.crc = 0x60;
  burst = burst.ReadPacket(packet);
  XCTAssertEqual(burst.burst_state().seqno, 4);

  packet.crc = 0x80;
  burst = burst.ReadPacket(packet);
  XCTAssertEqual(burst.burst_state().seqno, 5);

  packet.crc = 0xa0;
  burst = burst.ReadPacket(packet);
  XCTAssertEqual(burst.burst_state().seqno, 6);

  packet.crc = 0xc0;
  burst = burst.ReadPacket(packet);
  XCTAssertEqual(burst.burst_state().seqno, 1);
}

- (void)testEnd {
  VLPacket packet;
  packet.crc = 0xe0;

  viv::Burst burst = viv::Burst().ReadPacket(packet);
  XCTAssertFalse(burst.IsEmpty());
  XCTAssertTrue(burst.IsValid());
  XCTAssertTrue(burst.HasEnded());
}

@end
