// BluetoothManager.swift
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

/// Manage interaction with the `CoreBluetooth` system.
///
/// Observes the `bluetoothRequestStack` in the application state and triggers
/// bluetooth commands as necessary.
///
/// Commands manage their own dependencies.  If a dependency is not present, a
/// command will push an additional command to fulfil the dependency.  That new
/// command may have its own dependencies, which will be added when the stack
/// is next observed.
///
/// Instantiations of the `GenericBluetoothManager` type must conform to their
/// `Bluetooth.PeripheralDelegate` type.
///
/// - Parameter Bluetooth: A set of abstract types mirroring those in
///     `CoreBluetooth` to enable testing.
public class GenericBluetoothManager<Bluetooth: BluetoothTyping>: NSObject {
  fileprivate let store: Store
  fileprivate let centralManager: Bluetooth.CentralManager

  /// Peripherals that have been discovered advertising a heart rate monitor
  /// service.
  ///
  /// They form a queue: each peripheral will be added to the queue as it is
  /// discovered.  It will be removed from the queue after a connection has
  /// been established.
  private var discoveredPeripherals = [Bluetooth.Peripheral]()

  /// A Viiiiva peripheral that matches the device selection criteria.
  ///
  /// Only available after service discovery has found a Viiiiva service.
  private var viva: Bluetooth.Peripheral?

  /// The Viiiiva BLE service.
  private var vivaService: Bluetooth.Service?

  /// The Viiiiva's proprietary characteristic.
  private var vivaCharacteristic: Bluetooth.Characteristic?

  private var cancellable = Set<AnyCancellable>()

  init(store: Store, centralManager: Bluetooth.CentralManager) {
    self.store = store
    self.centralManager = centralManager
  }

  /// Register listeners for state changes.
  func connect() {
    store.receive(\.$bluetoothCommandStack)
      .sink { [weak self] (bluetoothCommandStack) in
        self?.dispatchNextCommand(bluetoothCommandStack)
      }
      .store(in: &cancellable)
    store.receive(\.$centralManagerState)
      .sink { [weak self] (state) in
        if let self = self, state == .poweredOn {
          self.dispatchNextCommand(self.store.state.bluetoothCommandStack)
        }
      }
      .store(in: &cancellable)
  }

  private func dispatchNextCommand(_ bluetoothCommandStack: [BluetoothCommand]) {
    guard let top = bluetoothCommandStack.last else { return }

    guard self.centralManager.state == .poweredOn else {
      self.store.state.message = .verboseError("waiting for Bluetooth to be turned on...")
      return
    }

    // Dispatch commands to the corresponding methods.
    switch top {
    case .findPeripheral:
      self.findPeripheral()
    case .connectToPeripheral:
      self.connectToPeripheral()
    case .discoverService:
      self.discoverService()
    case .discoverCharacteristic:
      self.discoverCharacteristic()
    case .connectCharacteristic:
      self.connectCharacteristic()
    case .writeViiiivaValue(let value):
      self.writeViiiivaValue(value)
    }
  }

  /// Returns a publisher for a particular peripheral.
  ///
  /// The publisher will retrieve the peripheral asynchronously once a
  /// subscription is received.  Subscribers will receive notifications on the
  /// store's dispatch queue.
  ///
  /// - Parameter uuid: The identifier for the peripheral.
  /// - Returns: A publisher that retrieves the peripheral.  May publish `nil`
  ///     if the peripheral could not be found.
  private func retrievePeripheral(by uuid: UUID) -> AnyPublisher<Bluetooth.Peripheral?, Never> {
    return Deferred { [weak self] in
      Just(self?.centralManager.retrievePeripherals(withIdentifiers: [uuid]).first)
    }
    .subscribe(on: DispatchQueue.global())
    .receive(on: store.dispatchQueue)
    .eraseToAnyPublisher()
  }

  /// Starts scanning for a Viiiiva device.
  private func scanForViiiiva() {
    guard !centralManager.isScanning else { return }

    // The Viiiiva won't respond to discovery for the non-standard Viiiiva
    // service (identified by CBUUID.vivaService).  Look for the heart rate
    // monitor service instead, and then connect and perform service discovery.
    //
    // Scanning continues until `didDiscoverVivaService` finds the Viiiiva
    // service.
    store.state.message = .verboseError("scanning for Viiiiva, make sure it's being worn...")
    centralManager.scanForPeripherals(withServices: [CBUUID.heartRateService], options: nil)
  }

  /// Registers the given peripheral and allows service discovery to proceed.
  private func didFindPeripheral(_ peripheral: Bluetooth.Peripheral) {
    // Self must conform to PeripheralDelegate.
    peripheral.delegate = (self as! Bluetooth.PeripheralDelegate)
    guard !discoveredPeripherals.contains(where: { $0 === peripheral }) else { return }

    discoveredPeripherals.append(peripheral)
    store.dispatch { $0.popCommand(.findPeripheral) }
  }

  /// Registers the Viiiiva service and stops peripheral discovery.
  ///
  /// - Parameter service: The discovered Viiiiva service.
  private func didDiscoverVivaService(_ service: Bluetooth.Service) {
    guard let peripheral = service.peripheral else {
      return
    }
    centralManager.stopScan()
    viva = peripheral
    vivaService = service
    let name = peripheral.name
    let uuid = peripheral.identifier
    store.dispatch { (state) in
      state.message = .verboseError("connected to device \"\(name ?? "")\" (\(uuid.uuidString))")
      state.lastConnectedDevice = uuid
      state.popCommand(.discoverService)
    }
  }

  // MARK: Command implementations

  private func findPeripheral() {
    switch store.state.deviceCriteria {
    case .byUuid(let uuid):
      retrievePeripheral(by: uuid)
        .sink { [weak self] peripheral in
          guard let self = self else { return }
          guard let peripheral = peripheral else {
            self.store
              .dispatch { (state) in
                state.message = .error("requested peripheral \(uuid) not found")
                state.shouldTerminate = true
              }
            return
          }
          self.didFindPeripheral(peripheral)
        }
        .store(in: &cancellable)
    case .byUuidWithFallback(let uuid):
      retrievePeripheral(by: uuid)
        .sink { [weak self] peripheral in
          guard let self = self else { return }
          guard let peripheral = peripheral else {
            // Fall back to a scan.
            self.scanForViiiiva()
            return
          }
          self.didFindPeripheral(peripheral)
        }
        .store(in: &cancellable)
    case .firstDiscovered:
      scanForViiiiva()
    }
  }

  private func connectToPeripheral() {
    guard let peripheral = discoveredPeripherals.first else {
      store.dispatch { $0.pushCommand(.findPeripheral) }
      return
    }
    let connectingStates: [CBPeripheralState] = [.connected, .connecting]
    if !connectingStates.contains(peripheral.state) {
      centralManager.connect(peripheral, options: nil)
    }
  }

  private func discoverService() {
    guard let peripheral = discoveredPeripherals.first, peripheral.state == .connected else {
      store.dispatch { $0.pushCommand(.connectToPeripheral) }
      return
    }

    if let service = peripheral.services?.first(where: { $0.uuid == CBUUID.vivaService }) {
      didDiscoverVivaService(service)
      return
    }

    peripheral.discoverServices([CBUUID.vivaService])
  }

  private func discoverCharacteristic() {
    guard let viva = viva, let vivaService = vivaService else {
      store.dispatch { $0.pushCommand(.discoverService) }
      return
    }

    viva.discoverCharacteristics([CBUUID.vivaCharacteristic], for: vivaService)
  }

  private func connectCharacteristic() {
    guard let viva = viva, let vivaCharacteristic = vivaCharacteristic else {
      store.dispatch { $0.pushCommand(.discoverCharacteristic) }
      return
    }

    viva.setNotifyValue(true, for: vivaCharacteristic)
  }

  private func writeViiiivaValue(_ value: Data) {
    guard let viva = viva, let vivaCharacteristic = vivaCharacteristic,
      vivaCharacteristic.isNotifying
    else {
      store.dispatch { $0.pushCommand(.connectCharacteristic) }
      return
    }

    viva.writeValue(value, for: vivaCharacteristic, type: .withResponse)
  }

  private func didConnectionError(_ error: Error) {
    store.dispatch { (state) in
      state.message = .verboseError(error.localizedDescription)
      state.exitStatus = .connectionError
      state.shouldTerminate = true
    }
  }

  // MARK: Generic CentralManagerDelegate methods

  func centralManagerDidUpdateState(_ central: Bluetooth.CentralManager) {
    let centralManagerState = central.state
    store.dispatch { (state) in
      state.centralManagerState = centralManagerState
    }
  }

  // swift-format-ignore: AlwaysUseLowerCamelCase
  func centralManager(
    _ central: Bluetooth.CentralManager, didDiscover peripheral: Bluetooth.Peripheral,
    advertisementData: [String: Any], rssi RSSI: NSNumber
  ) {
    // Ignore discovery if it didn't match device criteria.
    guard peripheral.fulfilsCriteria(store.state.deviceCriteria) else { return }

    didFindPeripheral(peripheral)
  }

  func centralManager(
    _ central: Bluetooth.CentralManager, didConnect peripheral: Bluetooth.Peripheral
  ) {
    store.dispatch { $0.popCommand(.connectToPeripheral) }
  }

  func centralManager(
    _ central: Bluetooth.CentralManager, didFailToConnect peripheral: Bluetooth.Peripheral,
    error: Error?
  ) {
    store.dispatch { (state) in
      state.message = .error("failed to connect to device \(peripheral.identifier)")
      if let error = error {
        state.message = .verboseError(error.localizedDescription)
      }
      state.exitStatus = .connectionError
      state.shouldTerminate = true
    }
  }

  func centralManager(
    _ central: Bluetooth.CentralManager, didDisconnectPeripheral peripheral: Bluetooth.Peripheral,
    error: Error?
  ) {
    store.dispatch { (state) in
      state.message = .error("device \(peripheral.identifier) disconnected")
      if let error = error {
        state.message = .verboseError(error.localizedDescription)
      }
      state.exitStatus = .connectionError
      state.shouldTerminate = true
    }
  }

  // MARK: Generic PeripheralDelegate methods

  func peripheral(
    _ peripheral: Bluetooth.Peripheral, didDiscoverServices error: Error?
  ) {
    guard error == nil else {

      return
    }

    assert(peripheral === discoveredPeripherals.first!)
    discoveredPeripherals.removeFirst()

    if let service = peripheral.services?.first(where: { $0.uuid == CBUUID.vivaService }) {
      didDiscoverVivaService(service)
    } else {
      centralManager.cancelPeripheralConnection(peripheral)
      store.dispatch { $0.popCommand(.discoverService) }
    }
  }

  func peripheral(
    _ peripheral: Bluetooth.Peripheral, didDiscoverCharacteristicsFor service: Bluetooth.Service,
    error: Error?
  ) {
    guard error == nil else {
      didConnectionError(error!)
      return
    }

    guard
      let characteristic = service.characteristics?
        .first(where: { $0.uuid == CBUUID.vivaCharacteristic })
    else { return }

    vivaCharacteristic = characteristic
    store.dispatch { $0.popCommand(.discoverCharacteristic) }
  }

  func peripheral(
    _ peripheral: Bluetooth.Peripheral, didUpdateValueFor characteristic: Bluetooth.Characteristic,
    error: Error?
  ) {
    guard error == nil else {
      didConnectionError(error!)
      return
    }

    guard let value = characteristic.value else { return }

    store.dispatch { $0.characteristicWrite = value }
  }

  func peripheral(
    _ peripheral: Bluetooth.Peripheral, didWriteValueFor characteristic: Bluetooth.Characteristic,
    error: Error?
  ) {
    guard error == nil else {
      didConnectionError(error!)
      return
    }

    store.dispatch { $0.popWriteViiiivaValueCommand() }
  }

  public func peripheral(
    _ peripheral: Bluetooth.Peripheral, didUpdateNotificationStateFor: Bluetooth.Characteristic,
    error: Error?
  ) {
    guard error == nil else {
      didConnectionError(error!)
      return
    }

    store.dispatch { $0.popCommand(.connectCharacteristic) }
  }
}

/// Bluetooth manager for use in production.
///
/// Binds `GenericBluetoothManager` to the concrete CoreBluetooth types
/// required for actual bluetooth communication.
///
/// Defines Objective C forwarding methods for delegate methods, to workaround
/// a Swift limitation that generic methods cannot be `@objc`.
public class BluetoothManager: GenericBluetoothManager<CoreBluetoothTypes>,
  CBCentralManagerDelegate, CBPeripheralDelegate
{
  // MARK: CBCentralManagerDelegate

  @objc public override func centralManagerDidUpdateState(_ central: CBCentralManager) {
    super.centralManagerDidUpdateState(central)
  }

  // swift-format-ignore: AlwaysUseLowerCamelCase
  @objc public override func centralManager(
    _ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
    advertisementData: [String: Any], rssi RSSI: NSNumber
  ) {
    super
      .centralManager(
        central, didDiscover: peripheral, advertisementData: advertisementData, rssi: RSSI)
  }

  @objc public override func centralManager(
    _ central: CBCentralManager, didConnect peripheral: CBPeripheral
  ) {
    super.centralManager(central, didConnect: peripheral)
  }

  @objc public override func centralManager(
    _ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?
  ) {
    super.centralManager(central, didFailToConnect: peripheral, error: error)
  }

  @objc public override func centralManager(
    _ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?
  ) {
    super.centralManager(central, didDisconnectPeripheral: peripheral, error: error)
  }

  // MARK: CBPeripheralDelegate

  @objc public override func peripheral(
    _ peripheral: CBPeripheral, didDiscoverServices error: Error?
  ) {
    super.peripheral(peripheral, didDiscoverServices: error)
  }

  @objc public override func peripheral(
    _ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService,
    error: Error?
  ) {
    super.peripheral(peripheral, didDiscoverCharacteristicsFor: service, error: error)
  }

  @objc public override func peripheral(
    _ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic,
    error: Error?
  ) {
    super.peripheral(peripheral, didUpdateValueFor: characteristic, error: error)
  }

  @objc public override func peripheral(
    _ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?
  ) {
    super.peripheral(peripheral, didWriteValueFor: characteristic, error: error)
  }

  @objc public override func peripheral(
    _ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic,
    error: Error?
  ) {
    super.peripheral(peripheral, didUpdateNotificationStateFor: characteristic, error: error)
  }
}

/// Command model for the Bluetooth system.
public enum BluetoothCommand: Equatable {
  /// Looks for a device matching the criteria.
  case findPeripheral

  /// Connects to the Viiiiva device.
  case connectToPeripheral

  /// Discovers the Viiiiva service.
  case discoverService

  /// Discovers the Viiiiva characteristic.
  case discoverCharacteristic

  /// Sets notifications for the Viiiiva characteristic.
  case connectCharacteristic

  /// Writes a GATT value to the Viiiiva characteristic.
  case writeViiiivaValue(value: Data)
}

extension State {
  /// Conditionally pops a bluetooth command from the stack.
  ///
  /// If the top (last element) of the stack is `command`, pop it.
  ///
  /// - Parameter command: The command to potentially pop.
  fileprivate func popCommand(_ command: BluetoothCommand) {
    if let top = bluetoothCommandStack.last, top == command {
      bluetoothCommandStack.removeLast()
    }
  }

  /// Conditionally pops a bluetooth command from the stack.
  ///
  /// If the top (last element) of the stack is `.writeViiiivaValue`, pop it.
  fileprivate func popWriteViiiivaValueCommand() {
    if let top = bluetoothCommandStack.last {
      switch top {
      case .writeViiiivaValue(_):
        bluetoothCommandStack.removeLast()
      default:
        break
      }
    }
  }

  /// Conditionally push a bluetooth command onto the stack.
  ///
  /// If the top (last element) of the stack is not `command`, push it.
  ///
  /// - Parameter command: The command to push.
  fileprivate func pushCommand(_ command: BluetoothCommand) {
    if let top = bluetoothCommandStack.last, top != command {
      bluetoothCommandStack.append(command)
    }
  }
}

/// Specifies which Viiiiva device to connect to.
enum DeviceCriteria {
  /// Connect to the first BLE device discovered with the Viiiiva
  /// service.
  case firstDiscovered

  /// Connect to the BLE device with the specified BLE UUUID.
  case byUuid(UUID)

  /// Attempt to connect to the BLE device with the specified UUID, falling
  /// back to a scan if the requested device was not found.
  case byUuidWithFallback(UUID)
}

extension BluetoothPeripheral {
  /// Whether this peripheral satisfies the device selection criteria.
  ///
  /// - Parameter criteria: The device selection criteria.
  /// - Returns: True if this peripheral satisfies the selection criteria.
  fileprivate func fulfilsCriteria(_ criteria: DeviceCriteria) -> Bool {
    switch criteria {
    case .byUuid(let uuid):
      return uuid == self.identifier
    case .byUuidWithFallback(_):
      return true
    case .firstDiscovered:
      return true
    }
  }
}

extension CBUUID {
  /// Bluetooth UUID used by Viiiiva heart rate monitors for a non-standard
  /// service.
  static let vivaService = CBUUID(string: "5B774111-D526-7B9A-4AE7-E59D015D79ED")

  /// Bluetooth UUID used by Viiiiva heart rate monitors for a non-standard
  /// characteristic.
  static let vivaCharacteristic = CBUUID(
    string: "5B774321-D526-7B9A-4AE7-E59D015D79ED")

  /// Identifier for the standard GATT heart rate monitor service.
  ///
  /// See: https://www.bluetooth.com/specifications/gatt/services/
  static let heartRateService = CBUUID(string: "180D")
}
