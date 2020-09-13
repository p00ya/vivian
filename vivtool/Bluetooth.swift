// Bluetooth.swift
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

/// Interface for binding a set of abstract bluetooth types.
///
/// Types that need to work with both CoreBluetooth and mocks should be
/// generic with a `<Bluetooth: BluetoothTyping>` type parameter.  To use
/// that type in production, instantiate it with `CoreBluetoothTypes` as
/// the `Bluetooth` type argument.
///
/// For testing, implement mocks conforming to the BluetoothXXX protocols,
/// and then instantiate the generic type with a `BluetoothTyping` that
/// specifies the mock types.
///
/// To test delegates, implement the methods on the generic type, but with
/// a different signature (e.g. `genericFooDidBar` instead of `fooDidBar`).
/// Then, derive a type using `CoreBluetoothTypes` from the generic type,
/// and forward the actual delegate methods to the generic methods.
public protocol BluetoothTyping {
  associatedtype CentralManager: BluetoothCentralManager where CentralManager.Bluetooth == Self
  associatedtype Peripheral: BluetoothPeripheral where Peripheral.Bluetooth == Self
  associatedtype Service: BluetoothService where Service.Bluetooth == Self
  associatedtype Characteristic: BluetoothCharacteristic where Characteristic.Bluetooth == Self
  associatedtype CentralManagerDelegate
  associatedtype PeripheralDelegate
}

/// Type bindings for CoreBluetooth classes.
public class CoreBluetoothTypes: BluetoothTyping {
  /// `CBCentralManager`.
  public typealias CentralManager = CBCentralManager

  /// `CBPeripheral`.
  public typealias Peripheral = CBPeripheral

  /// `CBService`.
  public typealias Service = CBService

  /// `CBCharacteristic`.
  public typealias Characteristic = CBCharacteristic

  /// `CBPeripheralDelegate`.
  public typealias PeripheralDelegate = CBPeripheralDelegate

  /// `CBCentralManagerDelegate`.
  public typealias CentralManagerDelegate = CBCentralManagerDelegate
}

/// An abstraction of `CBCentralManager` for mocking.
public protocol BluetoothCentralManager: AnyObject {
  associatedtype Bluetooth: BluetoothTyping
  typealias Peripheral = Bluetooth.Peripheral
  typealias CentralManagerDelegate = Bluetooth.CentralManagerDelegate

  var delegate: CentralManagerDelegate? { get set }
  var isScanning: Bool { get }
  var state: CBManagerState { get }

  func retrievePeripherals(withIdentifiers identifiers: [UUID]) -> [Peripheral]
  func retrieveConnectedPeripherals(withServices serviceUUIDs: [CBUUID]) -> [Peripheral]
  func scanForPeripherals(withServices serviceUUIDs: [CBUUID]?, options: [String: Any]?)
  func stopScan()
  func connect(_ peripheral: Peripheral, options: [String: Any]?)
  func cancelPeripheralConnection(_ peripheral: Peripheral)
}

extension CBCentralManager: BluetoothCentralManager {
  /// Set of bluetooth types consistent with Self.
  public typealias Bluetooth = CoreBluetoothTypes
}

/// An abstraction of `CBPeripheral` for mocking.
public protocol BluetoothPeripheral: AnyObject {
  associatedtype Bluetooth: BluetoothTyping
  typealias Characteristic = Bluetooth.Characteristic
  typealias Service = Bluetooth.Service
  typealias PeripheralDelegate = Bluetooth.PeripheralDelegate

  var identifier: UUID { get }
  var name: String? { get }
  var delegate: PeripheralDelegate? { get set }
  var state: CBPeripheralState { get }
  var services: [Service]? { get }
  var canSendWriteWithoutResponse: Bool { get }
  func readRSSI()
  func discoverServices(_ serviceUUIDs: [CBUUID]?)
  func discoverIncludedServices(_ includedServiceUUIDs: [CBUUID]?, for service: Service)
  func discoverCharacteristics(_ characteristicUUIDs: [CBUUID]?, for service: Service)
  func readValue(for characteristic: Characteristic)
  func maximumWriteValueLength(for type: CBCharacteristicWriteType) -> Int
  func writeValue(_ data: Data, for characteristic: Characteristic, type: CBCharacteristicWriteType)
  func setNotifyValue(_ enabled: Bool, for characteristic: Characteristic)
  func discoverDescriptors(for characteristic: Characteristic)
  func readValue(for descriptor: CBDescriptor)
  func writeValue(_ data: Data, for descriptor: CBDescriptor)
  func openL2CAPChannel(_ PSM: CBL2CAPPSM)
}

extension CBPeripheral: BluetoothPeripheral {
  /// Set of bluetooth types consistent with Self.
  public typealias Bluetooth = CoreBluetoothTypes
}

/// An abstraction of `CBService` for mocking.
public protocol BluetoothService: AnyObject {
  associatedtype Bluetooth: BluetoothTyping
  typealias Characteristic = Bluetooth.Characteristic
  typealias Peripheral = Bluetooth.Peripheral
  typealias Service = Bluetooth.Service

  var uuid: CBUUID { get }
  var peripheral: Peripheral { get }
  var isPrimary: Bool { get }
  var includedServices: [Service]? { get }
  var characteristics: [Characteristic]? { get }
}

extension CBService: BluetoothService {
  /// Set of bluetooth types consistent with Self.
  public typealias Bluetooth = CoreBluetoothTypes
}

/// An abstraction of `CBCharacteristic` for mocking.
public protocol BluetoothCharacteristic: AnyObject {
  associatedtype Bluetooth: BluetoothTyping
  typealias Service = Bluetooth.Service

  var uuid: CBUUID { get }
  var service: Service { get }
  var properties: CBCharacteristicProperties { get }
  var value: Data? { get }
  var descriptors: [CBDescriptor]? { get }
  var isNotifying: Bool { get }
}

extension CBCharacteristic: BluetoothCharacteristic {
  /// Set of bluetooth types consistent with Self.
  public typealias Bluetooth = CoreBluetoothTypes
}

public protocol BluetoothPeripheralDelegate {
  associatedtype Bluetooth: BluetoothTyping
}
