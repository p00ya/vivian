// TerminalManagerTests.swift
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

import ArgumentParser
import XCTest

class TerminalManagerTests: XCTestCase {
  private static var temporaryDirectoryURL: URL?
  private static let testTime = 1_577_836_800  // 2020-01-01Z00:00:00
  private static let directoryEntries = [
    VLDirectoryEntry(posix_time: testTime, length: 64, index: 1, file_type: .fitActivity)
  ]

  let state = State()
  var store: Store?
  var standardOutput = StringOutputStream()
  var standardError = StringOutputStream()
  var manager: TerminalManager<StringOutputStream>?

  override func setUp() {
    store = Store(state: state, dispatchQueue: DispatchQueue.main)
    standardOutput = StringOutputStream()
    standardError = StringOutputStream()
    manager = TerminalManager(
      store: store!, standardOutput: standardOutput, standardError: standardError)
  }

  func testConnect() throws {
    manager!.connect()
  }

  func testRenderMessage() throws {
    manager!.renderMessage(.error("test"))
    XCTAssertEqual(standardError.buffer, "test\n")
  }

  func testRenderDirectorySimple() throws {
    try manager!.renderDirectory(Self.directoryEntries, withOptions: VivtoolCommand.List.parse([]))
    XCTAssertEqual(standardOutput.buffer, "0001.fit\n")
  }

  func testRenderDirectoryLong() throws {
    let options = try VivtoolCommand.List.parse(["-l"])
    manager!.renderDirectory(Self.directoryEntries, withOptions: options)
    XCTAssertEqual(standardOutput.buffer, "64\t2020-01-01T00:00:00Z\t0001.fit\n")
  }

  func testRenderDirectoryHumanReadable() throws {
    let options = try VivtoolCommand.List.parse(["-l", "-h"])

    // We can't trust DateFormatter output to be stable.  DateFormatter uses
    // the user/system date format even with language/region specified in
    // Xcode's scheme.  Additionally, it might not be stable across system
    // versions.  Instead of a literal, just test equivalence with the
    // DateFormatter logic in the test.
    let timeFormatter = DateFormatter()
    timeFormatter.dateStyle = .short
    timeFormatter.timeStyle = .short
    let time = timeFormatter.string(
      from: Date(timeIntervalSince1970: TimeInterval(TerminalManagerTests.testTime)))

    manager!.renderDirectory(Self.directoryEntries, withOptions: options)
    XCTAssertEqual(standardOutput.buffer, "64 bytes\t\(time)\t0001.fit\n")
  }
}

class TerminalManagerStaticTests: XCTestCase {
  func testMakeFilename() throws {
    XCTAssertEqual(makeFilename(for: makeDirectoryEntry(index: 0x1)), "0001.fit")
    XCTAssertEqual(makeFilename(for: makeDirectoryEntry(index: 0xface)), "face.fit")
  }

  func testParseIndex() throws {
    XCTAssertEqual(parseIndex(from: "0001.fit"), 1)
    XCTAssertEqual(parseIndex(from: "face.fit"), 0xface)
  }

  func testVivtoolCommand() throws {
    _ = try VivtoolCommand.parseAsRoot(["--help"])
    XCTAssertThrowsError(try VivtoolCommand.parseAsRoot(["--moo"]))

    _ = try VivtoolCommand.parseAsRoot(["ls"])
    _ = try VivtoolCommand.parseAsRoot(["ls", "-l"])
    _ = try VivtoolCommand.parseAsRoot(["ls", "-l", "-h"])

    _ = try VivtoolCommand.parseAsRoot(["cp", "0001.fit", "dest.fit"])
    XCTAssertThrowsError(try VivtoolCommand.parseAsRoot(["cp", "0001.fit"]))
    XCTAssertThrowsError(try VivtoolCommand.parseAsRoot(["cp", "moo.fit"]))

    _ = try VivtoolCommand.parseAsRoot(["rm", "0001.fit"])
    XCTAssertThrowsError(try VivtoolCommand.parseAsRoot(["rm", "moo.fit"]))
    XCTAssertThrowsError(try VivtoolCommand.parseAsRoot(["rm", "0001.fit", "0002.fit"]))
    XCTAssertThrowsError(try VivtoolCommand.parseAsRoot(["rm"]))
  }
}

fileprivate func makeDirectoryEntry(index: UInt16) -> VLDirectoryEntry {
  return VLDirectoryEntry(posix_time: 0, length: 0, index: index, file_type: .fitActivity)
}
