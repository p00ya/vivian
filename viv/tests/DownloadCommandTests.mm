// DownloadCommandTests.mm - unit tests for viva/download_command.hpp
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

#include <cstdint>
#include <cstdlib>
#include <cstring>

#include "download_command.hpp"
#include "packet.h"

@interface DownloadCommandTests : XCTestCase

@end

@implementation DownloadCommandTests

- (void)testMakeCommandPacket {
  viv::DownloadCommand cmd(
      0x1234, 1, 0xffffffee, [](uint16_t, uint8_t const *, size_t) {});
  VLPacket const packet = cmd.MakeCommandPacket();

  XCTAssertEqual(packet.payload_length, 10);
  XCTAssertEqual(packet.payload[0], 0x34);
  XCTAssertEqual(packet.payload[2], 1);
  XCTAssertEqual(packet.payload[6], 0xee);
}

- (void)testReadPacket {
  VLPacket const ack = {
      0xfa,
      0,
      1,
      3,
      {0x0b, 0x81},
      {0x34, 0x12, 0, 0, 0, 0, 0x56, 0, 0, 0, 0, 0, 0, 0}};
  viv::DownloadCommand cmd(0x1234, [](uint16_t, uint8_t const *, size_t) {});
  XCTAssertEqual(cmd.ReadPacket(ack), 0);

  VLPacket const reply = {
      0x1a, 14,           1,
      3,    {0x0b, 0x03}, {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14}};
  int read = cmd.ReadPacket(reply);
  XCTAssertEqual(read, 14);
  XCTAssertEqual(memcmp(reply.payload, cmd.buffer(), 14), 0);
}

- (void)testReadPacketBadCmd {
  VLPacket const packet = {
      0xe6,
      0,
      1,
      3,
      {0x0b, 0x85 /* bad */},
      {0x34, 0x12, 0, 0, 0, 0, 0x56, 0, 0, 0, 0, 0, 0, 0}};
  viv::DownloadCommand cmd(0x1234, [](uint16_t, uint8_t const *, size_t) {});
  XCTAssertLessThan(cmd.ReadPacket(packet), 0);
}

@end
