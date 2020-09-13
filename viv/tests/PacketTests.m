// PacketTests.m - unit tests for viva/packet.h
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
#include <stdint.h>

#include "viv/packet.h"

@interface PacketTests : XCTestCase

@end

@implementation PacketTests

- (void)testWritePacket {
  VLPacket const packet = {
      9,
      4,
      0xaa,
      0xbb,
      {0xcc, 0xdd},
      {0xde, 0xad, 0xbe, 0xef, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}};
  uint8_t dst[10] = {0};
  VLWritePacket(dst, &packet);

  XCTAssertEqual(dst[0], packet.crc);
  XCTAssertEqual(dst[1], packet.payload_length);
  XCTAssertEqual(dst[2], packet.sender);
  XCTAssertEqual(dst[3], packet.receiver);
  XCTAssertEqual(dst[4], packet.cmd[0]);
  XCTAssertEqual(dst[6], packet.payload[0]);
}

- (void)testPacketSeqno {
  VLPacket packet;
  packet.crc = 0;
  XCTAssertEqual(VLPacketSeqno(&packet), 0);

  packet.crc = 1;
  XCTAssertEqual(VLPacketSeqno(&packet), 0);

  packet.crc = 0x20;
  XCTAssertEqual(VLPacketSeqno(&packet), 1);

  packet.crc = 0xe0;
  XCTAssertEqual(VLPacketSeqno(&packet), 7);
}

- (void)testPacketLength {
  VLPacket packet;
  packet.payload_length = 0;
  XCTAssertEqual(VLPacketLength(&packet), 6);

  packet.payload_length = 1;
  XCTAssertEqual(VLPacketLength(&packet), 7);
}

- (void)testDoesSeqnoMatch {
  XCTAssertNotEqual(VLDoesSeqnoMatch(0, 0), 0);
  XCTAssertNotEqual(VLDoesSeqnoMatch(1, 1), 0);
  XCTAssertNotEqual(VLDoesSeqnoMatch(6, 6), 0);
  XCTAssertNotEqual(VLDoesSeqnoMatch(7, 1), 0);
  XCTAssertNotEqual(VLDoesSeqnoMatch(7, 7), 0);

  XCTAssertEqual(VLDoesSeqnoMatch(0, 1), 0);
  XCTAssertEqual(VLDoesSeqnoMatch(0, 7), 0);
  XCTAssertEqual(VLDoesSeqnoMatch(1, 7), 0);
  XCTAssertEqual(VLDoesSeqnoMatch(2, 7), 0);
}

- (void)testGetNextSeqno {
  XCTAssertEqual(VLGetNextSeqno(0), 1);
  XCTAssertEqual(VLGetNextSeqno(1), 2);
  XCTAssertEqual(VLGetNextSeqno(6), 1);
}

- (void)testPacketMakePacket {
  VLPacket packet = VLMakePacket(kVLSeqnoEnd, 0x0600, nil, 0);
  XCTAssertEqual(packet.crc, 0xe3);
  XCTAssertEqual(packet.payload_length, 0);
  XCTAssertEqual(packet.sender, 3);
  XCTAssertEqual(packet.receiver, 1);
  XCTAssertEqual(packet.cmd[1], 6);
}

- (void)testMakeAckPacket {
  VLPacket ack = VLMakeAckPacket(0x050b);
  XCTAssertEqual(ack.cmd[1], 0x85);
}

- (void)testReadPacket {
  uint8_t const src[] = {0xfc, 1, 1, 3, 0xb, 5, 0};
  VLPacket packet;
  int err = VLReadPacket(&packet, src, sizeof(src));

  XCTAssertEqual(err, 0);
  XCTAssertEqual(packet.crc, 0xfc);
  XCTAssertEqual(packet.payload_length, 1);
  XCTAssertEqual(packet.sender, 1);
  XCTAssertEqual(packet.receiver, 3);
  XCTAssertEqual(packet.cmd[1], 5);
}

- (void)testValidatePacketFromVivaZero {
  VLPacket const packet = {0xfc, 1, 1, 3, {0xb, 5}};
  XCTAssertEqual(VLValidatePacketFromViva(&packet), 0);
}

- (void)testValidatePacketFromVivaNonzero {
  VLPacket const packet = {0xfc, 1, 3, 1, {0x0b, 0x05}};
  XCTAssertNotEqual(VLValidatePacketFromViva(&packet), 0);
}

@end
