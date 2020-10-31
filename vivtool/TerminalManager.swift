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

  init(store: Store, standardOutput: Stream, standardError: Stream) {
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

    store.receive(\.$clock)
      .sink { [weak self] (posixTime) in
        guard let self = self, let command = self.command as? VivtoolCommand.Clock else { return }
        self.renderClock(posixTime, withOptions: command)
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
        self?.renderDownloadedFile(index: downloadedFile.0, data: downloadedFile.1)
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
        updateFromCommonOptions(list.common)
        store.dispatch { (state) in
          state.setFromOptions(list.common)
          state.vivCommandQueue.append(.downloadDirectory)
        }
      case let copy as VivtoolCommand.Copy:
        updateFromCommonOptions(copy.common)
        guard let index = parseIndex(from: copy.file) else {
          VivtoolCommand.exit(withError: TerminalError.invalidSourceFile(copy.file))
        }
        self.destinationFile = copy.destinationFile()

        store.dispatch { (state) in
          state.setFromOptions(copy.common)
          state.vivCommandQueue.append(.downloadFile(index: index))
        }
      case let delete as VivtoolCommand.Delete:
        updateFromCommonOptions(delete.common)
        guard let index = parseIndex(from: delete.file) else {
          VivtoolCommand.exit(withError: TerminalError.invalidSourceFile(delete.file))
        }

        store.dispatch { (state) in
          state.setFromOptions(delete.common)
          state.vivCommandQueue.append(.deleteFile(index: index))
        }
      case let clock as VivtoolCommand.Clock:
        updateFromCommonOptions(clock.common)
        var vivCommands = [VivCommand]()
        if let time = clock.parseTime() {
          vivCommands.append(.setTime(time))
        }
        vivCommands.append(.downloadDirectory)
        store.dispatch { (state) in
          state.setFromOptions(clock.common)
          state.vivCommandQueue.append(contentsOf: vivCommands)
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

  func updateFromCommonOptions(_ options: VivtoolCommand.CommonOptions) {
    verbose = options.verbose
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

  func renderClock(_ posixTime: time_t, withOptions command: VivtoolCommand.Clock) {
    let date = Date(timeIntervalSince1970: TimeInterval(posixTime))
    var time: String
    if command.humanReadable {
      let timeFormatter = DateFormatter()
      timeFormatter.dateStyle = .short
      timeFormatter.timeStyle = .short
      time = timeFormatter.string(from: date)
    } else {
      time = ISO8601DateFormatter().string(from: date)
    }
    print(time, to: &standardOutput)
    store.dispatch { $0.shouldTerminate = true }
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

  private func renderDownloadedFile(index: UInt16, data: Data) {
    do {
      // destinationFile is set to non-nil in run().
      try data.write(to: destinationFile!)
    } catch {
      let destinationFile = self.destinationFile!
      store.dispatch { (state) in
        state.message = .error("error writing to \"\(destinationFile)\"")
        state.message = .verboseError(error.localizedDescription)
        state.exitStatus = .conditionError
        state.shouldTerminate = true
      }
    }

    store.dispatch { $0.shouldTerminate = true }
  }

  private func renderDeletedFile(_ index: UInt16, ok: Bool) {
    store.dispatch { (state) in
      if !ok {
        let hexIndex = String(format: "%04x", index)
        state.message = .error("Error deleting file at index \(hexIndex)")
        state.exitStatus = .conditionError
      }
      state.shouldTerminate = true
    }
  }

  func terminate() {
    exit(store.state.exitStatus.rawValue)
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

extension State {
  fileprivate func setFromOptions(_ options: VivtoolCommand.CommonOptions) {
    if let uuid = options.uuid {
      deviceCriteria = .byUuid(uuid)
    } else if let uuid = lastConnectedDevice {
      deviceCriteria = .byUuidWithFallback(uuid)
    }
  }
}

/// Defines the subcommands and their options.
struct VivtoolCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "vivtool",
    abstract: "A utility for interacting with Viiiiva devices.",
    subcommands: [List.self, Copy.self, Delete.self, Clock.self],
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

  struct Clock: ParsableCommand {
    static let configuration = CommandConfiguration(
      commandName: "date", abstract: "Print or set the device clock.")

    @OptionGroup var common: CommonOptions

    @Flag(name: .customShort("h"), help: "Used localized time formats.")
    var humanReadable = false

    @Option(name: [.customShort("s"), .long], help: "Set the device clock to the given time.")
    var time: String?

    /// Parses the date option.
    ///
    /// If the `-h` flag is specified, the time will be parsed using the default
    /// locale.  Without `-h`, it must be in ISO8601 time format.  It can also
    /// be specified as the string `now` for the current time.
    ///
    /// - Returns: The parsed date, or `none`.
    func parseTime() -> Date? {
      guard let dateString = self.time else {
        return .none
      }

      if dateString == "now" {
        return Date()
      } else if humanReadable {
        return DateFormatter().date(from: dateString)
      } else {
        return ISO8601DateFormatter().date(from: dateString)
      }
    }
  }

  /// Validates a Viiiiva filename.
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

/// Process exit status.
enum ExitStatus: Int32 {
  /// Successful execution of the command.
  case success = 0

  /// Error communicating with the Viiiiva device; probably retriable.
  case connectionError = 1

  /// Error that will probably not go away without changing something (e.g.
  /// the command invocation).
  case conditionError = 2
}
