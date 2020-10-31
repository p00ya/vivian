// SetTimeCommandTests.m - unit tests for viva/set_time_command.hpp
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

#include "set_time_command.hpp"

@interface SetTimeCommandTests : XCTestCase

@end

@implementation SetTimeCommandTests

- (void)testMakeCommandPacket {
  viv::SetTimeCommand cmd(0x12345678, [](bool) {});
  VLPacket const packet = cmd.MakeCommandPacket();

  XCTAssertEqual(packet.payload_length, 4);
  XCTAssertEqual(packet.payload[0], 0x78);
}

@end
