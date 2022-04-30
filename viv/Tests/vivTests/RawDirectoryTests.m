// RawDirectoryTests.m - unit tests for viva/raw_directory.h
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

@import Viv;

@interface RawDirectoryTests : XCTestCase

@end

@implementation RawDirectoryTests

- (void)testReadDirectoryHeader {
  uint8_t const src[] = {
      1, 16, 0, 0, 0, 0, 0, 0, 0x12, 0x34, 0x14, 0x39, 0, 0, 0, 0,
  };
  VLDirectoryHeader dir;
  int read = VLReadDirectoryHeader(&dir, src, sizeof(src));
  XCTAssertEqual(read, 16);
  XCTAssertEqual(dir.time[0], 0x12);
}

- (void)testReadNextDirectoryEntry {
  uint8_t const src[] = {
      2, 0, 16, 4, 2, 0, 0, 96, 192, 1, 0, 0, 0x12, 0x34, 0x14, 0x39,
  };
  VLRawDirectoryEntry entry;
  int read = VLReadNextDirectoryEntry(&entry, src, sizeof(src));
  XCTAssertEqual(read, 16);
  XCTAssertEqual(entry.file_id[0], 2);
  XCTAssertEqual(entry.time[0], 0x12);
  XCTAssertEqual(entry.file_type, 16);
  XCTAssertEqual(entry.subtype, 4);
}

@end
