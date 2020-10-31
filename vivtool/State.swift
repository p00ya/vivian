// State.swift
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
import CoreBluetooth

/// Encapsulates the "application state".
///
/// Note the "application state" isn't supposed to capture all state within the
/// app.  Rather, it's the state that forms the interface between different
/// components of the app.
///
/// All changes to the state should be by dispatching to the `Store`, with the
/// exception of subscribing to publishers and writing to the `@Passthrough`
/// properties.
///
/// `@Published` publishers will dispatch on the wrapped value's `willSet`
/// method.  This means that the value received by subscribers will not yet be
/// applied to the `State` object when using the default subscription!
///
/// To get a consistent view (along with transactional reducer behaviour),
/// subscribers should subscribe to the publishers using `Store.receive`.
class State {
  /// Whether the process should exit.
  @Published var shouldTerminate = false

  /// The exit status of the process.
  @Published var exitStatus = ExitStatus.success

  /// The bluetooth state on the host machine.
  @Published var centralManagerState = CBManagerState.poweredOff

  /// User criteria for which device to connect to.
  ///
  /// Must not change after the first bluetooth command is issued.
  var deviceCriteria = DeviceCriteria.firstDiscovered

  /// A stack of bluetooth commands for `BluetoothManager`.
  ///
  /// The last element of the array corresponds to the top of the stack.
  /// Commands may push additional commands to satisfy their dependencies.
  @Published var bluetoothCommandStack = [BluetoothCommand]()

  /// Publisher of value notifications from the Viiiiva's BLE characteristic.
  ///
  /// Writes can be made directly (rather than via a reducer on the store).
  @Passthrough var characteristicWrite: Data

  /// Publisher for messages that should be written to the terminal.
  ///
  /// Writes can be made directly (rather than via a reducer on the store).
  @Passthrough var message: TerminalMessage

  /// A queue of commands for `VivManager`.
  ///
  /// The first element will be processed next.
  @Published var vivCommandQueue = [VivCommand]()

  /// The time according to the Viiiiva's clock.
  ///
  /// Published when parsing the directory.
  @Published var clock: time_t = 0

  /// All directory entries from the last directory download.
  @Published var directory = [VLDirectoryEntry]()

  /// Publisher of downloaded files.
  ///
  /// The tuple consists of the file index and contents.
  @Passthrough var downloadedFile: (UInt16, Data)

  /// Publisher of deleted files.
  ///
  /// The tuple consists of the file index and the deletion success.
  @Passthrough var deletedFile: (UInt16, Bool)

  /// UUID of the last Viiiva to be connected.
  ///
  /// This state is persisted between invocations, via UserDefaults.
  @Published var lastConnectedDevice: UUID?
}
