// main.swift
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

import CoreBluetooth
import Dispatch

let dispatchQueue = DispatchQueue.main
var store = Store(state: State(), dispatchQueue: dispatchQueue)
let centralManager = CBCentralManager(delegate: nil, queue: dispatchQueue)
let bluetoothManager = BluetoothManager(store: store, centralManager: centralManager)
centralManager.delegate = bluetoothManager
let protocolManager = VLProtocolManager()
let vivManager = VivManager(store: store, protocolManager: protocolManager)
protocolManager.delegate = vivManager
let terminalManager = TerminalManager(
  store: store, standardOutput: FileOutputStream(FileHandle.standardOutput),
  standardError: FileOutputStream(FileHandle.standardError))
let userDefaultsManager = UserDefaultsManager(store: store, userDefaults: UserDefaults.standard)

bluetoothManager.connect()
userDefaultsManager.connect()
terminalManager.connect()
vivManager.connect()

dispatchQueue.async {
  terminalManager.run()
}

dispatchMain()
