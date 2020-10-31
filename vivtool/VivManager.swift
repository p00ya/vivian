// VivManager.swift
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

/// Bridge between vivtool and the libviv manager.
class VivManager: NSObject {
  /// Idle period before timing out.
  ///
  /// If the protocol manager has been waiting more than this period since it
  /// was last notified of a value, it will be sent a timeout notification
  /// and the application will terminate.
  private static let timeoutInterval = DispatchTimeInterval.seconds(16)

  private let store: Store

  /// A manager for encoding and decoding messages to Viiiiva
  /// devices over GATT values.
  private let protocolManager: VLProtocolManager

  /// Whether the manager is busy with a command.
  ///
  /// If true, no new commands should be issued to the manager.
  private var isBusy = false

  /// Notifies the manager that it has been waiting for too long.
  private var timeout: DispatchWorkItem?

  /// Subscriptions.
  private var cancellable = Set<AnyCancellable>()

  /// All directory entries received since last download directory
  /// command.
  ///
  /// This is used to buffer entries before they are written to the
  /// application state.
  private var directory = [VLDirectoryEntry]()

  /// Creates a manager that bridges the given store and manager.
  ///
  /// - Parameters:
  ///     - store: The application store to subscribe and dispatch
  ///         reducers to.
  ///     - protocolManager: A closure that returns a manager
  ///         for encoding and decoding messages to Viiiiva devices
  ///         to GATT values.
  init(store: Store, protocolManager: VLProtocolManager) {
    self.store = store
    self.protocolManager = protocolManager
  }

  /// Subscribes to updates from the store.
  func connect() {
    store.receive(\.$vivCommandQueue)
      .sink { [weak self] (_) in
        self?.dispatchNextCommand()
      }
      .store(in: &cancellable)
    store.receive(\.$characteristicWrite)
      .sink { [weak self] (value) in
        guard let self = self else { return }
        if self.isBusy {
          self.restartTimer()
        }

        self.protocolManager.notifyValue(value)
      }
      .store(in: &cancellable)
  }

  fileprivate func dispatchNextCommand() {
    guard !self.isBusy else { return }
    switch store.state.vivCommandQueue.first {
    case .downloadDirectory:
      self.downloadDirectory()
    case .downloadFile(let index):
      self.downloadFile(index: index)
    case .deleteFile(let index):
      self.deleteFile(index: index)
    case .setTime(let time):
      self.setTime(time)
    case nil:
      // Queue is empty, do nothing.
      break
    }
  }

  fileprivate func restartTimer() {
    if let timeout = timeout {
      timeout.cancel()
    }

    let timeout = DispatchWorkItem(block: { [weak self] in self?.didTimeout() })
    self.timeout = timeout
    store.dispatchQueue.asyncAfter(
      deadline: DispatchTime.now().advanced(by: Self.timeoutInterval), execute: timeout)
  }

  fileprivate func didTimeout() {
    protocolManager.notifyTimeout()
    store.dispatch { (state) in
      state.message = .error("timed out waiting for value from Viiiiva")
      state.exitStatus = .connectionError
      state.shouldTerminate = true
    }
  }

  // MARK: Commands

  func downloadDirectory() {
    assert(!self.isBusy)

    self.isBusy = true
    self.protocolManager.downloadDirectory()
  }

  func downloadFile(index: UInt16) {
    assert(!self.isBusy)

    self.isBusy = true
    self.protocolManager.downloadFile(index)
  }

  func deleteFile(index: UInt16) {
    assert(!self.isBusy)

    self.isBusy = true
    self.protocolManager.eraseFile(index)
  }

  func setTime(_ time: Date) {
    assert(!self.isBusy)

    self.isBusy = true
    // Rounding upward before truncation will compensate for the lag in actually
    // updating the device.
    self.protocolManager.setTime(time_t(ceil(time.timeIntervalSince1970)))
  }
}

extension VivManager: VLProtocolManagerDelegate {
  func writeValue(_ data: Data) -> Int32 {
    store.dispatch { $0.bluetoothCommandStack.append(.writeViiiivaValue(value: data)) }
    return 0
  }

  func didStartWaiting() {
    restartTimer()
  }

  func didFinishWaiting() {
    timeout?.cancel()
    isBusy = false
  }

  func didError(_ error: Error) {
    store.dispatch { (store) in
      store.message = .error(error.localizedDescription)
      store.exitStatus = .conditionError
      store.shouldTerminate = true
    }
  }

  func didParseClock(_ posixTime: time_t) {
    store.dispatch { (store) in
      store.clock = posixTime
    }
  }

  func didParseDirectoryEntry(_ entry: VLDirectoryEntry) {
    directory.append(entry)
  }

  func didFinishParsingDirectory() {
    store.dispatch { [weak self] (state) in
      guard let self = self else { return }

      state.directory = self.directory
      state.dequeCommand(.downloadDirectory)
    }
  }

  func didDownloadFile(_ index: UInt16, data: Data) {
    store.dispatch { (state) in
      state.downloadedFile = (index, data)
      state.dequeCommand(.downloadFile(index: index))
    }
  }

  func didEraseFile(_ index: UInt16, successfully ok: Bool) {
    store.dispatch { (state) in
      state.deletedFile = (index, ok)
      state.dequeCommand(.deleteFile(index: index))
    }
  }

  func didSetTime(_ ok: Bool) {
    store.dispatch { (state) in
      guard let currentCommand = state.vivCommandQueue.first else { return }
      switch currentCommand {
      case .setTime(_):
        state.dequeCommand(currentCommand)
      default:
        assertionFailure("unexpected didSetTime")
        break
      }
    }
  }
}

/// Commands to control `VivManager`.
public enum VivCommand: Equatable {
  /// Command to download the Viiiiva's file directory.
  case downloadDirectory

  /// Command to download a single file.
  case downloadFile(index: UInt16)

  /// Command to delete a single file.
  case deleteFile(index: UInt16)

  /// Command to set the Viiiiva's clock to the given time.
  case setTime(_ time: Date)
}

extension State {
  /// Removes the front of the command queue.
  ///
  /// - Parameter command: The command which must be at the front
  ///     of the queue.
  fileprivate func dequeCommand(_ command: VivCommand) {
    assert(vivCommandQueue.first! == command)
    vivCommandQueue.removeFirst()
  }
}
