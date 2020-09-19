// Renderer.swift
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
import Combine

/// Manager for command-line arguments and output.
///
/// This manager issues commands via the application store based on
/// parsing arguments from the command line.  It renders messages from the
/// commands to the terminal and writes downloaded files to the filesystem.
///
/// Also handles terminating the process with the appropriate exit status.
class TerminalManager<Stream: TextOutputStream> {
  private var cancellable = Set<AnyCancellable>()

  private var command: ParsableCommand?

  private var verbose = false

  private var destinationFile: URL?

  private let store: Store

  private var standardOutput: Stream
  private var standardError: Stream

  init(
    store: Store, standardOutput: Stream,
    standardError: Stream
  ) {
    self.store = store
    self.standardOutput = standardOutput
    self.standardError = standardError
  }

  /// Connects to the application store.
  func connect() {
    store.receive(\.$shouldTerminate)
      .sink { (shouldTerminate) in
        if shouldTerminate {
          self.terminate()
        }
      }
      .store(in: &cancellable)

    store.receive(\.$message)
      .sink { [weak self] (message) in
        self?.renderMessage(message)
      }
      .store(in: &cancellable)

    store.receive(\.$directory)
      .sink { [weak self] (directory) in
        guard let self = self, let command = self.command as? VivtoolCommand.List else { return }
        self.renderDirectory(directory, withOptions: command)
      }
      .store(in: &cancellable)

    store.receive(\.$downloadedFile)
      .sink { [weak self] (downloadedFile) in
        self?.renderDownloadedFile(downloadedFile.1)
      }
      .store(in: &cancellable)

    store.receive(\.$deletedFile)
      .sink { [weak self] (deletedFile) in
        self?.renderDeletedFile(deletedFile.0, ok: deletedFile.1)
      }
      .store(in: &cancellable)
  }

  /// Parses the command line arguments and runs commands.
  func run() {
    do {
      command = try VivtoolCommand.parseAsRoot()

      switch command {
      case let list as VivtoolCommand.List:
        verbose = list.common.verbose
        store.dispatch { (state) in
          if let uuid = list.common.uuid {
            state.deviceCriteria = .byUuid(uuid)
          }
          state.vivCommandQueue.append(.downloadDirectory)
        }
      case let copy as VivtoolCommand.Copy:
        verbose = copy.common.verbose
        guard let index = parseIndex(from: copy.file) else {
          VivtoolCommand.exit(withError: TerminalError.invalidSourceFile(copy.file))
        }
        self.destinationFile = copy.destinationFile()

        store.dispatch { (state) in
          if let uuid = copy.common.uuid {
            state.deviceCriteria = .byUuid(uuid)
          }
          state.vivCommandQueue.append(.downloadFile(index: index))
        }
      case let delete as VivtoolCommand.Delete:
        verbose = delete.common.verbose
        guard let index = parseIndex(from: delete.file) else {
          VivtoolCommand.exit(withError: TerminalError.invalidSourceFile(delete.file))
        }

        store.dispatch { (state) in
          if let uuid = delete.common.uuid {
            state.deviceCriteria = .byUuid(uuid)
          }
          state.vivCommandQueue.append(.deleteFile(index: index))
        }
      default:
        // Let ArgumentParser print help output.
        VivtoolCommand.main()
        store.dispatch { $0.shouldTerminate = true }
      }
    } catch {
      VivtoolCommand.exit(withError: error)
    }
  }

  // MARK: Renderers

  func renderMessage(_ terminalMessage: TerminalMessage) {
    let message: String
    switch terminalMessage {
    case .error(let m):
      message = m
    case .verboseError(let m):
      if !verbose { return }
      message = m
    }
    print(message, to: &standardError)
  }

  func renderDirectory(_ directory: [VLDirectoryEntry], withOptions command: VivtoolCommand.List) {
    let entryRenderer: (VLDirectoryEntry) -> Void
    if !command.longFormat {
      var standardOutput = self.standardOutput
      entryRenderer = { print("\(makeFilename(for: $0))", to: &standardOutput) }
    } else if command.humanReadable {
      let fileSizeFormatter = ByteCountFormatter()
      let timeFormatter = DateFormatter()
      timeFormatter.dateStyle = .short
      timeFormatter.timeStyle = .short
      entryRenderer = { [weak self] in
        self?
          .renderLocalizedDirectoryEntry(
            $0, withFileSizeFormatter: fileSizeFormatter,
            timeFormatter: timeFormatter)
      }
    } else {
      entryRenderer = renderDirectoryEntry(_:)
    }
    directory.filter({ $0.file_type == .fitActivity }).forEach(entryRenderer)
    store.dispatch { $0.shouldTerminate = true }
  }

  func renderDirectoryEntry(_ entry: VLDirectoryEntry) {
    let date = Date(timeIntervalSince1970: TimeInterval(entry.posix_time))
    let time = ISO8601DateFormatter().string(from: date)
    let filename = makeFilename(for: entry)
    print("\(entry.length)\t\(time)\t\(filename)", to: &standardOutput)
  }

  private func renderLocalizedDirectoryEntry(
    _ entry: VLDirectoryEntry, withFileSizeFormatter fileSizeFormatter: ByteCountFormatter,
    timeFormatter: DateFormatter
  ) {
    let fileSize = fileSizeFormatter.string(fromByteCount: Int64(entry.length))
    let date = Date(timeIntervalSince1970: TimeInterval(entry.posix_time))
    let time = timeFormatter.string(from: date)
    let filename = makeFilename(for: entry)
    print("\(fileSize)\t\(time)\t\(filename)", to: &standardOutput)
  }

  private func renderDownloadedFile(_ data: Data) {
    do {
      // destinationFile is set to non-nil in run().
      try data.write(to: destinationFile!)
    } catch {
      VivtoolCommand.exit(withError: error)
    }

    store.dispatch { $0.shouldTerminate = true }
  }

  private func renderDeletedFile(_ index: UInt16, ok: Bool) {
    store.dispatch { (state) in
      if !ok {
        let hexIndex = String(format: "%04x", index)
        state.message = .error("Error deleting file at index \(hexIndex)")
        state.exitStatus = 1
      }
      state.shouldTerminate = true
    }
  }

  func terminate() {
    exit(store.state.exitStatus)
  }
}

/// Formats the filename for an activity file.
///
/// The Viiiiva filesystem doesn't actually give files names, just indices.
/// This function synthesizes a filename by encoding the index as 4 hexadecimal
/// digits and appending a ".fit" extension.
///
/// - Parameter entry: The entry for an activity file.
/// - Returns: A formatted filename for the given entry, e.g. "0001.fit".
func makeFilename(for entry: VLDirectoryEntry) -> String {
  return String(format: "%04x.fit", entry.index)
}

/// Parses the 16-bit index out of a filename.
///
/// This is the inverse of `makeFilename`.
///
/// - Parameter filename: 4 hex digits followed by a ".fit" extension, e.g.
///     "0001.fit".
/// - Returns: The parsed index or nil.
func parseIndex(from filename: String) -> UInt16? {
  UInt16(filename.prefix(4), radix: 16)
}

/// Defines the subcommands and their options.
struct VivtoolCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "vivatool",
    abstract: "A utility for interacting with Viiiiva devices.",
    subcommands: [List.self, Copy.self, Delete.self],
    helpNames: [.long, .customShort("?")])
}

extension VivtoolCommand {
  struct CommonOptions: ParsableCommand {
    @Flag(name: [.customShort("v"), .long], help: "Output extra information and warnings.")
    var verbose = false

    @Option(help: "The device to connect to.", transform: Self.parseUUID)
    var uuid: UUID?

    private static func parseUUID(uuidString: String) -> UUID? {
      return UUID(uuidString: uuidString)
    }
  }

  struct List: ParsableCommand {
    static let configuration = CommandConfiguration(
      commandName: "ls", abstract: "List directory contents.")

    @OptionGroup var common: CommonOptions

    @Flag(name: .customShort("l"), help: "Output table with size and time.")
    var longFormat = false

    @Flag(name: .customShort("h"), help: "With -l, output localized sizes and times.")
    var humanReadable = false
  }

  struct Copy: ParsableCommand {
    static let configuration = CommandConfiguration(
      commandName: "cp", abstract: "Copy file.")

    @OptionGroup var common: CommonOptions

    @Argument(help: "Viiiiva filename, e.g. \"0001.fit\".")
    var file: String

    @Argument(help: "Destination filename or directory.")
    var destination: String

    mutating func validate() throws {
      guard isValidFilename(file) else {
        throw ValidationError("\(file) is not a valid Viiiiva filename.")
      }
    }

    func destinationFile() -> URL {
      let destination = URL(fileURLWithPath: self.destination)
      return destination.hasDirectoryPath
        ? destination.appendingPathComponent(file, isDirectory: false) : destination
    }
  }

  struct Delete: ParsableCommand {
    static let configuration = CommandConfiguration(
      commandName: "rm", abstract: "Delete file.")

    @OptionGroup var common: CommonOptions

    @Argument(help: "Viiiiva filename, e.g. \"0001.fit\".")
    var file: String

    mutating func validate() throws {
      guard isValidFilename(file) else {
        throw ValidationError("\(file) is not a valid Viiiiva filename.")
      }
    }
  }

  /// Validates a Viiiva filename.
  ///
  /// - Parameter file: The filename to validate.
  /// - Returns: True if the filename was valid.
  static func isValidFilename(_ file: String) -> Bool {
    return file.range(of: "[0-9a-f]{4}.fit", options: .regularExpression) != nil
  }
}

enum TerminalMessage {
  /// A message thath should be written to stderr.
  case error(String)

  /// A message that should only be written if the user requested verbose output.
  case verboseError(String)
}

fileprivate enum TerminalError: Error {
  case invalidSourceFile(String)
}
