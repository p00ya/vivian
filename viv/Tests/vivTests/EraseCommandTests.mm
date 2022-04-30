// EraseCommandTests.mm - unit tests for viva/erase_command.hpp
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

#include "viv/erase_command.hpp"

@interface EraseCommandTests : XCTestCase

@end

@implementation EraseCommandTests

- (void)testMakeCommandPacket {
  viv::EraseCommand cmd(0x1234, [](bool) {});
  VLPacket const packet = cmd.MakeCommandPacket();

  XCTAssertEqual(packet.payload_length, 2);
  XCTAssertEqual(packet.payload[0], 0x34);
}

- (void)testReadPacket {
  VLPacket const ack = {0xe9, 0, 1, 3, {0x0b, 0x84}};
  bool replyOk = false;
  viv::EraseCommand cmd(0x1234, [&replyOk](bool ok) { replyOk = ok; });
  int err = cmd.ReadPacket(ack);
  XCTAssertEqual(err, 0);

  VLPacket const reply = {0xfc, 1, 1, 3, {0x0b, 0x05}, {0}};
  err = cmd.ReadPacket(reply);
  XCTAssertEqual(err, 0);
  XCTAssertTrue(cmd.MaybeFinish());
  XCTAssertTrue(replyOk);
}

- (void)testReadPacketError {
  VLPacket const ack = {0xe9, 0, 1, 3, {0x0b, 0x84}};
  bool replyOk = false;
  viv::EraseCommand cmd(0x1234, [&replyOk](bool ok) { replyOk = ok; });
  int err = cmd.ReadPacket(ack);
  XCTAssertEqual(err, 0);

  VLPacket const reply = {0xfb, 1, 1, 3, {0x0b, 0x05}, {1}};
  err = cmd.ReadPacket(reply);
  XCTAssertEqual(err, 0);
  XCTAssertTrue(cmd.MaybeFinish());
  XCTAssertFalse(replyOk);
}

@end
