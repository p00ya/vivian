// VivManagerTests.swift
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

class VivManagerTests: XCTestCase {
  private static let timeout = TimeInterval(1.0)

  let store = Store(state: State(), dispatchQueue: DispatchQueue.main)
  var cancellable = Set<AnyCancellable>()
  var protocolManager = FakeProtocolManager()
  var manager: VivManager?

  override func setUp() {
    manager = VivManager(store: store, protocolManager: protocolManager)
  }

  func testCharacteristicWrite() {
    manager!.connect()
    let testData = Data(base64Encoded: "dGVzdA==")!  // "test"
    store.state.characteristicWrite = testData

    wait(for: [protocolManager.expectation], timeout: Self.timeout)
    XCTAssertEqual(protocolManager.commands, [.notifyValue(testData)])
  }

  func testDownloadDirectory() {
    manager!.connect()
    store.state.vivCommandQueue.append(.downloadDirectory)

    wait(for: [protocolManager.expectation], timeout: Self.timeout)
    XCTAssertEqual(protocolManager.commands, [.downloadDirectory])
  }

  func testDownloadFile() {
    manager!.connect()
    store.state.vivCommandQueue.append(.downloadFile(index: 0x1337))

    wait(for: [protocolManager.expectation], timeout: Self.timeout)
    XCTAssertEqual(protocolManager.commands, [.downloadFile(0x1337)])
  }

  func testEraseFile() {
    manager!.connect()
    store.state.vivCommandQueue.append(.deleteFile(index: 0x1337))

    wait(for: [protocolManager.expectation], timeout: Self.timeout)
    XCTAssertEqual(protocolManager.commands, [.eraseFile(0x1337)])
  }

  func testSetTime() {
    manager!.connect()
    let posixTime = 1_577_836_800  // 2020-01-01
    let date = Date(timeIntervalSince1970: TimeInterval(posixTime))
    store.state.vivCommandQueue.append(.setTime(date))

    wait(for: [protocolManager.expectation], timeout: Self.timeout)
    XCTAssertEqual(protocolManager.commands, [.setTime(posixTime)])
  }
}

/// Fake implementation of `VLProtocolManager` for testing.
///
/// Each method will record the invocation in `commands`, and then fulfill
/// `expectation`.
class FakeProtocolManager: VLProtocolManager {
  enum Command: Equatable {
    case notifyValue(Data)
    case notifyTimeout
    case downloadDirectory
    case downloadFile(UInt16)
    case eraseFile(UInt16)
    case setTime(time_t)
  }

  let expectation = XCTestExpectation(description: "FakeProtocolManager")
  var commands = [Command]()

  override func notifyValue(_ data: Data) {
    commands.append(.notifyValue(data))
    expectation.fulfill()
  }

  override func notifyTimeout() {
    commands.append(.notifyTimeout)
    expectation.fulfill()
  }

  override func downloadDirectory() {
    commands.append(.downloadDirectory)
    expectation.fulfill()
  }

  override func downloadFile(_ index: UInt16) {
    commands.append(.downloadFile(index))
    expectation.fulfill()
  }

  override func eraseFile(_ index: UInt16) {
    commands.append(.eraseFile(index))
    expectation.fulfill()
  }

  override func setTime(_ posixTime: time_t) {
    commands.append(.setTime(posixTime))
    expectation.fulfill()
  }
}
