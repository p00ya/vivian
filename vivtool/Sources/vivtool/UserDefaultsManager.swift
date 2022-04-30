// UserDefaultsManager.swift
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
import Foundation

/// Manager for command-line arguments and output.
///
/// This manager issues commands via the application store based on
/// parsing arguments from the command line.  It renders messages from the
/// commands to the terminal and writes downloaded files to the filesystem.
///
/// Also handles terminating the process with the appropriate exit status.
class UserDefaultsManager {
  private static let lastConnectedDeviceUuidKey = "LastConnectedDeviceUuid"

  private var cancellable = Set<AnyCancellable>()

  private let store: Store
  private let userDefaults: UserDefaults

  init(store: Store, userDefaults: UserDefaults) {
    self.store = store
    self.userDefaults = userDefaults
  }

  /// Loads preferences and connects to the application store.
  func connect() {
    loadDefaults()
    store.receive(\.$lastConnectedDevice)
      // @Published publishes the value at the time of subscription, which
      // we ignore because we just set it in loadDefaults().
      .dropFirst()
      .sink { [weak self] (lastConnectedDevice) in
        guard let self = self else { return }
        if let uuid = lastConnectedDevice {
          self.userDefaults.setValue(uuid.uuidString, forKey: Self.lastConnectedDeviceUuidKey)
        } else {
          self.userDefaults.removeObject(forKey: Self.lastConnectedDeviceUuidKey)
        }
      }
      .store(in: &cancellable)
  }

  /// Populates state from the user preferences.
  func loadDefaults() {
    if let uuidString = userDefaults.string(forKey: Self.lastConnectedDeviceUuidKey) {
      if let uuid = UUID(uuidString: uuidString) {
        store.dispatch {
          $0.lastConnectedDevice = uuid
        }
      } else {
        // UUID in preferences is corrupt; erase it.
        userDefaults.removeObject(forKey: Self.lastConnectedDeviceUuidKey)
      }
    }
  }
}
