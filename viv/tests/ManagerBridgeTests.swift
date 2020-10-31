// ManagerBridgeTests.swift - tests for viva/manager_bridge.h
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

import XCTest

class ManagerTests: XCTestCase {
  var delegate: VLCProtocolManagerDelegate!
  var events: [String] = []
  var directoryEntries: [VLDirectoryEntry] = []
  var data: [UInt8]?

  static func logDelegateEvent(managerTests: UnsafeMutableRawPointer, event: String) {
    managerTests.assumingMemoryBound(to: ManagerTests.self).pointee.events.append(event)
  }

  static func captureData(
    managerTests: UnsafeMutableRawPointer, data: UnsafePointer<UInt8>, length: Int
  ) {
    let buf = UnsafeBufferPointer<UInt8>(start: data, count: length)
    managerTests.assumingMemoryBound(to: ManagerTests.self).pointee.data = Array<UInt8>.init(buf)
  }

  static func captureDirectoryEntry(
    managerTests: UnsafeMutableRawPointer, entry: VLDirectoryEntry
  ) {
    managerTests.assumingMemoryBound(to: ManagerTests.self).pointee.directoryEntries.append(entry)
  }

  override func setUp() {
    delegate = VLCProtocolManagerDelegate(
      write_value: { (p, value, length) -> Int32 in
        ManagerTests.logDelegateEvent(managerTests: p!, event: "writeValue")
        return 0
      },
      did_start_waiting: { p in
        ManagerTests.logDelegateEvent(managerTests: p!, event: "didStartWaiting")
      },
      did_finish_waiting: { p in
        ManagerTests.logDelegateEvent(managerTests: p!, event: "didFinishWaiting")
      },
      did_error: { (p, err, _) in
        ManagerTests.logDelegateEvent(managerTests: p!, event: "didError: \(err)")
      },
      did_parse_clock: { (p, posixTime) in
        ManagerTests.logDelegateEvent(managerTests: p!, event: "didParseClock(\(posixTime))")
      },
      did_parse_directory_entry: { (p, entry) in
        ManagerTests.logDelegateEvent(managerTests: p!, event: "didParseDirectoryEntry")
        ManagerTests.captureDirectoryEntry(managerTests: p!, entry: entry)
      },
      did_finish_parsing_directory: { p in
        ManagerTests.logDelegateEvent(managerTests: p!, event: "didFinishParsingDirectory")
      },
      did_download_file: { (p, index, data, length) -> Void in
        ManagerTests.logDelegateEvent(
          managerTests: p!, event: "didDownloadFile(\(index))")
        ManagerTests.captureData(managerTests: p!, data: data, length: length)
      },
      did_erase_file: { (p, index, ok) in
        let ok = ok != 0
        ManagerTests.logDelegateEvent(managerTests: p!, event: "didEraseFile(\(index), \(ok))")
      },
      did_set_time: { (p, ok) in
        let ok = ok != 0
        ManagerTests.logDelegateEvent(managerTests: p!, event: "didSetTime(\(ok))")
      })
  }

  override func tearDown() {
    events.removeAll()
  }

  func testDownloadFile() throws {
    var selfRef = self
    let manager = VLCProtocolManager.init(ctx: &selfRef, delegate: delegate)
    defer { manager.deinitialize() }

    manager.downloadFile(index: 0x1234)
    XCTAssertEqual(events.removeLast(), "didStartWaiting")
    XCTAssertEqual(events.removeLast(), "writeValue")

    // Specifies a 28-byte file.
    let writeAck: ContiguousArray<UInt8> = [
      0xfd,
      10,
      1,
      3,
      0x0b, 0x81,
      0x34, 0x12, 0, 0, 0, 0, 28, 0, 0, 0,
    ]
    writeAck.withUnsafeBufferPointer { buffer in
      manager.notifyValue(value: buffer.baseAddress!, length: buffer.count)
    }
    XCTAssert(events.isEmpty)
    let writeResponse: ContiguousArray<UInt8> = [
      0x1a,
      14,
      1,
      3,
      0x0b, 0x03,
      1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14,
    ]
    writeResponse.withUnsafeBufferPointer { buffer in
      manager.notifyValue(value: buffer.baseAddress!, length: buffer.count)
    }
    let writeResponse2: ContiguousArray<UInt8> = [
      0xe7,
      14,
      1,
      3,
      0x0b, 0x03,
      15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28,
    ]
    writeResponse2.withUnsafeBufferPointer { buffer in
      manager.notifyValue(value: buffer.baseAddress!, length: buffer.count)
    }

    XCTAssertEqual(events.removeLast(), "didFinishWaiting")
    XCTAssertEqual(events.removeLast(), "didDownloadFile(4660)")
    XCTAssert(events.isEmpty)
    XCTAssert(data != nil)

    if data != nil {
      XCTAssert(data!.elementsEqual(1...28))
    }
  }

  func testDownloadDirectory() throws {
    var selfRef = self
    let manager = VLCProtocolManager.init(ctx: &selfRef, delegate: delegate)
    defer { manager.deinitialize() }

    manager.downloadDirectory()
    XCTAssertEqual(events.removeLast(), "didStartWaiting")
    XCTAssertEqual(events.removeLast(), "writeValue")

    // Specifies 2 records (header + 1 file).
    let writeAck: ContiguousArray<UInt8> = [
      0xff,
      10,
      1,
      3,
      0x0b, 0x81,
      0, 0, 0, 0, 0, 0, 2, 0, 0, 0,
    ]
    writeAck.withUnsafeBufferPointer { buffer in
      manager.notifyValue(value: buffer.baseAddress!, length: buffer.count)
    }
    XCTAssert(events.isEmpty)

    // Series of 3 notifications contain a directory header and one entry.
    let writeResponse: ContiguousArray<UInt8> = [
      0x1f,
      14,
      1,
      3,
      0x0b, 0x03,
      // Directory header:
      1, 0x10, 0, 0, 0, 0, 0, 0, 0x12, 0x34, 0x56, 0x78, 0, 0,
    ]
    writeResponse.withUnsafeBufferPointer { buffer in
      manager.notifyValue(value: buffer.baseAddress!, length: buffer.count)
    }
    XCTAssert(events.isEmpty)
    let writeResponse2: ContiguousArray<UInt8> = [
      0x3e,
      14,
      1,
      3,
      0x0b, 0x03,
      // Directory header (cont.):
      0, 0,
      // Start directory entry:
      2, 0, 0x80, 4, 2, 0, 0, 0x60, 28, 0, 0, 0,
    ]
    writeResponse2.withUnsafeBufferPointer { buffer in
      manager.notifyValue(value: buffer.baseAddress!, length: buffer.count)
    }
    XCTAssert(events.isEmpty)
    let writeResponse3: ContiguousArray<UInt8> = [
      0xe2,
      4,
      1,
      3,
      0x0b, 0x03,
      // Directory entry (cont.):
      0x11, 0x34, 0x56, 0x78,
    ]
    writeResponse3.withUnsafeBufferPointer { buffer in
      manager.notifyValue(value: buffer.baseAddress!, length: buffer.count)
    }

    XCTAssertEqual(events.removeLast(), "didFinishWaiting")
    XCTAssertEqual(events.removeLast(), "didFinishParsingDirectory")
    XCTAssertEqual(events.removeLast(), "didParseDirectoryEntry")
    XCTAssertEqual(events.removeLast(), "didParseClock(2649980946)")
    XCTAssert(events.isEmpty)

    XCTAssertEqual(directoryEntries.count, 1)
    if directoryEntries.count == 1 {
      XCTAssertEqual(directoryEntries[0].posix_time, 2_649_980_945)
      XCTAssertEqual(directoryEntries[0].length, 28)
      XCTAssertEqual(directoryEntries[0].index, 2)
      XCTAssertEqual(directoryEntries[0].file_type, .fitActivity)
    }
  }

  func testEraseFile() throws {
    var selfRef = self
    let manager = VLCProtocolManager.init(ctx: &selfRef, delegate: delegate)
    defer { manager.deinitialize() }

    manager.eraseFile(index: 1)
    XCTAssertEqual(events.removeLast(), "didStartWaiting")
    XCTAssertEqual(events.removeLast(), "writeValue")
    XCTAssert(events.isEmpty)

    let writeAck: ContiguousArray<UInt8> = [0xe9, 0, 1, 3, 0x0b, 0x84]
    writeAck.withUnsafeBufferPointer { buffer in
      manager.notifyValue(value: buffer.baseAddress!, length: buffer.count)
    }
    XCTAssert(events.isEmpty)

    let eraseResponse: ContiguousArray<UInt8> = [0xfc, 1, 1, 3, 0x0b, 0x05, 0]
    eraseResponse.withUnsafeBufferPointer { buffer in
      manager.notifyValue(value: buffer.baseAddress!, length: buffer.count)
    }

    XCTAssertEqual(events.removeLast(), "writeValue")
    XCTAssertEqual(events.removeLast(), "didFinishWaiting")
    XCTAssertEqual(events.removeLast(), "didEraseFile(1, true)")
    XCTAssert(events.isEmpty)
  }

  func testSetTime() throws {
    var selfRef = self
    let manager = VLCProtocolManager.init(ctx: &selfRef, delegate: delegate)
    defer { manager.deinitialize() }

    manager.setTime(posixTime: 0x1234_5678)
    XCTAssertEqual(events.removeLast(), "didStartWaiting")
    XCTAssertEqual(events.removeLast(), "writeValue")
    XCTAssert(events.isEmpty)

    let writeAck: ContiguousArray<UInt8> = [0xed, 0, 1, 3, 0x08, 0x81]
    writeAck.withUnsafeBufferPointer { buffer in
      manager.notifyValue(value: buffer.baseAddress!, length: buffer.count)
    }
    XCTAssertEqual(events.removeLast(), "didFinishWaiting")
    XCTAssertEqual(events.removeLast(), "didSetTime(true)")
    XCTAssert(events.isEmpty)
  }
}
