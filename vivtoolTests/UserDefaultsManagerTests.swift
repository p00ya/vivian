// UserDefaultsManagerTests.swift
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

import Combine
import Dispatch
import XCTest

class UserDefaultsManagerTests: XCTestCase {
  private static let timeout = TimeInterval(2.0)
  private static let fastTimeout = DispatchQueue.SchedulerTimeType.Stride(0.2)

  let store = Store(state: State(), dispatchQueue: DispatchQueue.main)
  let userDefaults = UserDefaults()
  var cancellable = Set<AnyCancellable>()
  var manager: UserDefaultsManager?

  override func setUp() {
    manager = UserDefaultsManager(store: store, userDefaults: userDefaults)
  }

  func testConnectWithEmptyDefaults() throws {
    userDefaults.removeObject(forKey: "LastConnectedDeviceUuid")

    let expectation = XCTestExpectation(description: "lastConnectedDevice")
    store.state.$lastConnectedDevice.timeout(1, scheduler: DispatchQueue.main)
      .collect()
      .sink { (uuids) in
        XCTAssertEqual(uuids, [nil])
        expectation.fulfill()
      }
      .store(in: &cancellable)

    manager!.connect()
    wait(for: [expectation], timeout: Self.timeout)
  }

  func testConnectWithDefaults() throws {
    let testUuid = "A556FF53-8A57-43E1-AF96-64277025BEFB"
    userDefaults.setValue(testUuid, forKey: "LastConnectedDeviceUuid")

    let expectation = XCTestExpectation(description: "lastConnectedDevice")
    store.state.$lastConnectedDevice.timeout(Self.fastTimeout, scheduler: DispatchQueue.main)
      .collect()
      .sink { (uuids) in
        XCTAssertNil(uuids[0])
        XCTAssertEqual(uuids[1]?.uuidString, testUuid)
        expectation.fulfill()
      }
      .store(in: &cancellable)

    manager!.connect()
    wait(for: [expectation], timeout: Self.timeout)
  }

  func testConnectWithInvalidDefaults() throws {
    let testUuid = "invalid"
    userDefaults.setValue(testUuid, forKey: "LastConnectedDeviceUuid")
    let expectation = XCTestExpectation(description: "lastConnectedDevice")
    store.state.$lastConnectedDevice.timeout(Self.fastTimeout, scheduler: DispatchQueue.main)
      .collect()
      .sink { (uuids) in
        XCTAssertEqual(uuids, [nil])
        expectation.fulfill()
      }
      .store(in: &cancellable)

    manager!.connect()
    XCTAssertNil(userDefaults.string(forKey: "LastConnectedDeviceUuid"))
  }
}
