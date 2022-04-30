// TimeTests.m - unit tests for viva/time.h
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

@import Viv;

@interface TimeTests : XCTestCase

@end

@implementation TimeTests

- (void)testGetVivaTimeFromPosix {
  XCTAssertEqual(
      VLGetVivaTimeFromPosix(631065600UL), 0U, "1989-12-31Z00:00:00");
  XCTAssertEqual(
      VLGetVivaTimeFromPosix(1577836800UL), 946771200U, "2020-01-01Z00:00:00");
}

- (void)testGetPosixTimeFromViva {
  XCTAssertEqual(
      VLGetPosixTimeFromViva(0U), 631065600UL, "1989-12-31Z00:00:00");
  XCTAssertEqual(
      VLGetPosixTimeFromViva(946771200U), 1577836800UL, "2020-01-01Z00:00:00");
}

@end
