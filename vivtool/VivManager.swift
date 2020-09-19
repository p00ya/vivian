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

/// Bridge between vivtool and the libviv manager.
class VivManager: NSObject {
  private let store: Store

  /// A manager for encoding and decoding messages to Viiiiva
  /// devices over GATT values.
  private let protocolManager: VLProtocolManager

  /// Whether the manager is busy with a command.
  ///
  /// If true, no new commands should be issued to the manager.
  private var isBusy = false

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
        self?.protocolManager.notifyValue(value)
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
    default:
      // Queue is empty, do nothing.
      break
    }
  }

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
}

extension VivManager: VLProtocolManagerDelegate {
  func writeValue(_ data: Data) -> Int32 {
    store.dispatch { $0.bluetoothCommandStack.append(.writeViiiivaValue(value: data)) }
    return 0
  }

  func didStartWaiting() {
    // TODO: set timeout
  }

  func didFinishWaiting() {
    // TODO: cancel timeout
  }

  func didError(_ error: Error) {
    store.dispatch { (store) in
      store.shouldTerminate = true
    }
    fatalError(error.localizedDescription)
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
}

/// Commands to control `VivManager`.
public enum VivCommand: Equatable {
  /// Command to download the Viiiiva's file directory.
  case downloadDirectory

  /// Command to download a single file.
  case downloadFile(index: UInt16)

  /// Command to delete a single file.
  case deleteFile(index: UInt16)
}

extension State {
  /// Removes the front of the command queue.
  ///
  /// - Parameter command: The command which must be at the front
  ///    of the queue.
  fileprivate func dequeCommand(_ command: VivCommand) {
    assert(vivCommandQueue.first! == command)
    vivCommandQueue.removeFirst()
  }
}
