// ManagerObjcBridgeTests.m - tests for manager_objc_bridge.h
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

#import <Foundation/Foundation.h>
#import <XCTest/XCTest.h>

@import Viv;

@interface TestManagerDelegate : NSObject <VLProtocolManagerDelegate>

@property NSMutableArray<NSString *> *events;

@end

@interface ManagerObjcBridgeTests : XCTestCase

@property(nullable) TestManagerDelegate *delegate;

@end

@implementation ManagerObjcBridgeTests

- (void)setUp {
  self.delegate = [[TestManagerDelegate alloc] init];
}

- (void)testSetTime {
  VLProtocolManager *manager =
      [[VLProtocolManager alloc] initWithDelegate:self.delegate];
  XCTAssertNotNil(manager);
  [manager setTime:0x12345678];
  NSArray *setTimeEvents = @[ @"writeValue", @"didStartWaiting" ];
  XCTAssertEqualObjects(self.delegate.events, setTimeEvents);
  [self.delegate.events removeAllObjects];

  static const char writeAck[] = {0xed, 0, 1, 3, 0x08, 0x81};
  NSData *data = [[NSData alloc] initWithBytesNoCopy:(void *)writeAck
                                              length:sizeof(writeAck)
                                        freeWhenDone:NO];
  [manager notifyValue:data];
  XCTAssertEqualObjects(self.delegate.events, @[ @"didFinishWaiting" ]);
}

@end

@implementation TestManagerDelegate

- (instancetype)init {
  self = [super init];
  _events = [[NSMutableArray alloc] init];
  return self;
}

- (int)writeValue:(NSData *)data {
  [self.events addObject:@"writeValue"];
  return 0;
}

- (void)didStartWaiting {
  [self.events addObject:@"didStartWaiting"];
}

- (void)didFinishWaiting {
  [self.events addObject:@"didFinishWaiting"];
}

@end
