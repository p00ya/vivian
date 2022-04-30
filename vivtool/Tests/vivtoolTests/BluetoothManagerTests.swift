// BluetoothManagerTests.swift
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
import XCTest
@testable import vivtool

class BluetoothManagerTests: XCTestCase {
  private static let timeout = TimeInterval(2.0)
  private static let testPeripheralUUID = UUID(uuidString: "A556FF53-8A57-43E1-AF96-64277025BEFB")!

  let store = Store(state: State(), dispatchQueue: DispatchQueue.main)
  var cancellable = Set<AnyCancellable>()
  var centralManager = FakeCentralManager()
  var manager: FakeBluetoothManager?

  var peripheral: FakePeripheral?
  var service: FakeService?
  var characteristic: FakeCharacteristic?

  override func setUpWithError() throws {
    let manager = FakeBluetoothManager(store: store, centralManager: centralManager)
    centralManager.delegate = manager
    self.manager = manager
    manager.connect()

    let peripheral = FakePeripheral(identifier: Self.testPeripheralUUID, name: "Fake")
    let service = peripheral.registerService(uuid: CBUUID.vivaService)
    characteristic = service.registerCharacteristic(uuid: CBUUID.vivaCharacteristic)
    _ = peripheral.registerService(uuid: CBUUID.heartRateService)
    self.service = service
    self.peripheral = peripheral
    centralManager.peripherals.append(peripheral)
  }

  func testFindPeripheralWithScan() {
    store.state.deviceCriteria = .firstDiscovered
    store.state.bluetoothCommandStack.append(.findPeripheral)

    let scanForPeripherals = XCTestExpectation(description: "scanForPeripherals")
    centralManager.expectation = scanForPeripherals
    wait(for: [scanForPeripherals], timeout: Self.timeout)
    XCTAssert(centralManager.isScanning)
    XCTAssertEqual(centralManager.scanServices, [CBUUID.heartRateService])

    manager!
      .centralManager(centralManager, didDiscover: peripheral!, advertisementData: [:], rssi: 80)
    waitUntilCommandStackIsEmpty()
  }

  func testConnectToPeripheral() {
    store.state.deviceCriteria = .byUuid(Self.testPeripheralUUID)
    store.state.bluetoothCommandStack.append(.connectToPeripheral)

    waitUntilCommandStackIsEmpty()
    XCTAssertEqual(peripheral!.state, .connected)
  }

  func testDiscoverService() {
    store.state.deviceCriteria = .byUuid(Self.testPeripheralUUID)
    store.state.bluetoothCommandStack.append(.discoverService)

    waitUntilCommandStackIsEmpty()
    XCTAssertEqual(store.state.lastConnectedDevice, Self.testPeripheralUUID)
  }

  func testDiscoverCharacteristic() {
    store.state.deviceCriteria = .byUuid(Self.testPeripheralUUID)
    store.state.bluetoothCommandStack.append(.discoverCharacteristic)

    waitUntilCommandStackIsEmpty()
  }

  func testConnectCharacteristic() {
    store.state.deviceCriteria = .byUuid(Self.testPeripheralUUID)
    store.state.bluetoothCommandStack.append(.connectCharacteristic)

    waitUntilCommandStackIsEmpty()
    XCTAssert(characteristic?.isNotifying ?? false)
  }

  func testWriteViiiivaValue() {
    store.state.deviceCriteria = .byUuid(Self.testPeripheralUUID)
    let testData = Data(base64Encoded: "dGVzdA==")!  // "test"
    store.state.bluetoothCommandStack.append(.writeViiiivaValue(value: testData))

    waitUntilCommandStackIsEmpty()
    XCTAssertEqual(characteristic!.lastWrittenValue, testData)
  }

  /// Waits for the bluetooth command stack to reach the specified state.
  ///
  /// Runs the main thread until the store's bluetooth command stack is equal
  /// to `stack`.  The initial state is ignored, even if it matches.
  ///
  /// - Parameter stack: The target state of the command stack.
  private func waitUntilCommandStackEquals(_ stack: [BluetoothCommand]) {
    let commandStackToMatch = XCTestExpectation(description: "commandStackToMatch")
    store.state.$bluetoothCommandStack
      .dropFirst()
      .drop(while: { $0 != stack })
      .sink { _ in
        commandStackToMatch.fulfill()
      }
      .store(in: &cancellable)
    wait(for: [commandStackToMatch], timeout: Self.timeout)
  }

  /// Waits for the bluetooth command stack to become empty.
  private func waitUntilCommandStackIsEmpty() {
    waitUntilCommandStackEquals([])
  }
}

/// Cohesive set of fake types for CoreBluetooth.
class FakeBluetoothTypes: BluetoothTyping {
  typealias CentralManager = FakeCentralManager
  typealias Peripheral = FakePeripheral
  typealias Service = FakeService
  typealias Characteristic = FakeCharacteristic
  typealias PeripheralDelegate = FakePeripheralDelegate
  typealias CentralManagerDelegate = FakeCentralManagerDelegate
}

class FakeBluetoothManager: GenericBluetoothManager<FakeBluetoothTypes>, FakeCentralManagerDelegate,
  FakePeripheralDelegate
{
}

/// PeripheralDelegate for use with `GenericBluetoothManager`.
///
/// The methods correspond to those in `CBPeripheralDelegate`.
protocol FakePeripheralDelegate {
  typealias Bluetooth = FakeBluetoothTypes
  typealias Characteristic = Bluetooth.Characteristic
  typealias Peripheral = Bluetooth.Peripheral
  typealias Service = Bluetooth.Service

  func peripheral(
    _ peripheral: Peripheral, didDiscoverServices error: Error?
  )

  func peripheral(
    _ peripheral: Peripheral, didDiscoverCharacteristicsFor service: Service,
    error: Error?
  )

  func peripheral(
    _ peripheral: Peripheral, didUpdateValueFor characteristic: Characteristic,
    error: Error?
  )

  func peripheral(
    _ peripheral: Peripheral, didWriteValueFor characteristic: Characteristic,
    error: Error?
  )

  func peripheral(
    _ peripheral: Peripheral, didUpdateNotificationStateFor: Characteristic,
    error: Error?
  )
}

/// CentralManagerDelegate for use with `GenericBluetoothManager`.
///
/// The methods correspond to those in `CBCentralManagerDelegate`.
protocol FakeCentralManagerDelegate {
  typealias Bluetooth = FakeBluetoothTypes
  typealias CentralManager = Bluetooth.CentralManager
  typealias Peripheral = Bluetooth.Peripheral

  func centralManagerDidUpdateState(_ central: CentralManager)

  // swift-format-ignore: AlwaysUseLowerCamelCase
  func centralManager(
    _ central: CentralManager, didDiscover peripheral: Peripheral,
    advertisementData: [String: Any], rssi RSSI: NSNumber
  )

  func centralManager(
    _ central: CentralManager, didConnect peripheral: Peripheral
  )

  func centralManager(
    _ central: CentralManager, didFailToConnect peripheral: Peripheral,
    error: Error?
  )

  func centralManager(
    _ central: CentralManager, didDisconnectPeripheral peripheral: Peripheral,
    error: Error?
  )
}

/// "Working" implementation of a CentralManager.
class FakeCentralManager: BluetoothCentralManager {
  typealias Bluetooth = FakeBluetoothTypes

  var expectation: XCTestExpectation?
  var delegate: CentralManagerDelegate?
  var isScanning = false
  var state = CBManagerState.poweredOn
  var peripherals = [Peripheral]()
  var connectedPeripherals = [Peripheral]()

  var scanServices: [CBUUID]?

  func retrievePeripherals(withIdentifiers identifiers: [UUID]) -> [Peripheral] {
    fulfillAfter()
    return peripherals.filter { identifiers.contains($0.identifier) }
  }

  func retrieveConnectedPeripherals(withServices serviceUUIDs: [CBUUID]) -> [Peripheral] {
    fulfillAfter()
    return connectedPeripherals
  }

  func scanForPeripherals(withServices serviceUUIDs: [CBUUID]?, options: [String: Any]?) {
    fulfillAfter()
    scanServices = serviceUUIDs
    isScanning = true
  }

  func stopScan() {
    isScanning = false
  }

  func connect(_ peripheral: Peripheral, options: [String: Any]?) {
    self.connectedPeripherals.append(peripheral)
    peripheral.state = .connected
    self.delegate?.centralManager(self, didConnect: peripheral)
  }

  func cancelPeripheralConnection(_ peripheral: Peripheral) {
    connectedPeripherals.removeAll { $0.identifier == peripheral.identifier }
  }

  private func fulfillAfter() {
    DispatchQueue.main.async { [weak self] in
      self?.expectation?.fulfill()
    }
  }
}

/// "Somewhat working" implementation of a Peripheral.
class FakePeripheral: BluetoothPeripheral {
  typealias Bluetooth = FakeBluetoothTypes
  typealias Characteristic = Bluetooth.Characteristic
  typealias Service = Bluetooth.Service
  typealias PeripheralDelegate = Bluetooth.PeripheralDelegate

  var identifier: UUID
  var name: String?
  var delegate: PeripheralDelegate?
  var state = CBPeripheralState.disconnected
  var services: [Service]? = []
  var canSendWriteWithoutResponse = false

  init(identifier: UUID, name: String?) {
    self.identifier = identifier
    self.name = name
  }

  func readRSSI() {}

  func discoverServices(_ serviceUUIDs: [CBUUID]?) {
    delegate?.peripheral(self, didDiscoverServices: nil)
  }

  func discoverIncludedServices(_ includedServiceUUIDs: [CBUUID]?, for service: Service) {}

  func discoverCharacteristics(_ characteristicUUIDs: [CBUUID]?, for service: Service) {
    delegate?.peripheral(self, didDiscoverCharacteristicsFor: service, error: nil)
  }

  func readValue(for characteristic: Characteristic) {}

  func maximumWriteValueLength(for type: CBCharacteristicWriteType) -> Int {
    return 32
  }

  func writeValue(_ data: Data, for characteristic: Characteristic, type: CBCharacteristicWriteType)
  {
    characteristic.lastWrittenValue = data
    switch type {
    case .withResponse:
      delegate?.peripheral(self, didWriteValueFor: characteristic, error: nil)
    default:
      break
    }
  }

  func setNotifyValue(_ enabled: Bool, for characteristic: Characteristic) {
    characteristic.isNotifying = true
    delegate?.peripheral(self, didUpdateNotificationStateFor: characteristic, error: nil)
  }

  func discoverDescriptors(for characteristic: Characteristic) {}
  func readValue(for descriptor: CBDescriptor) {}
  func writeValue(_ data: Data, for descriptor: CBDescriptor) {}
  // swift-format-ignore: AlwaysUseLowerCamelCase
  func openL2CAPChannel(_ PSM: CBL2CAPPSM) {}
}

/// "Working" implementation of a bluetooth Service.
class FakeService: BluetoothService {
  typealias Bluetooth = FakeBluetoothTypes

  var uuid: CBUUID
  var peripheral: Peripheral?
  var isPrimary = true
  var includedServices: [Service]?
  var characteristics: [Characteristic]? = []

  init(uuid: CBUUID, peripheral: FakePeripheral) {
    self.uuid = uuid
    self.peripheral = peripheral
  }
}

extension FakePeripheral {
  /// Creates and registers a service with this peripheral.
  ///
  /// - Parameter uuid: The UUID of the service.
  /// - Returns: The new service.
  func registerService(uuid: CBUUID) -> FakeService {
    let service = FakeService(uuid: uuid, peripheral: self)
    self.services?.append(service)
    return service
  }
}

/// "Working" implementation of a bluetooth Characteristic.
class FakeCharacteristic: BluetoothCharacteristic {
  typealias Bluetooth = FakeBluetoothTypes

  var uuid: CBUUID
  var service: Service?
  var properties = CBCharacteristicProperties()
  var value: Data?
  var descriptors: [CBDescriptor]?
  var isNotifying = false

  var lastWrittenValue: Data?

  init(uuid: CBUUID, service: FakeService) {
    self.uuid = uuid
    self.service = service
  }
}

extension FakeService {
  /// Creates and registers a characteristic with this service.
  ///
  /// - Parameter uuid: The UUID of the characteristic.
  /// - Returns: The new characteristic.
  func registerCharacteristic(uuid: CBUUID) -> FakeCharacteristic {
    let characteristic = FakeCharacteristic(uuid: uuid, service: self)
    self.characteristics?.append(characteristic)
    return characteristic
  }
}
