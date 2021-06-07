/**
 * Copyright (c) 2017 Razeware LLC
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
 * distribute, sublicense, create a derivative work, and/or sell copies of the
 * Software in any work that is designed, intended, or marketed for pedagogical or
 * instructional purposes related to programming, coding, application development,
 * or information technology.  Permission for such use, copying, modification,
 * merger, publication, distribution, sublicensing, creation of derivative works,
 * or sale is expressly withheld.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

/**
 Marked comments added by Mostafa Mazrouh
 */


import UIKit
import CoreBluetooth


class HRMViewController: UIViewController {
  
  @IBOutlet weak var heartRateLabel: UILabel!
  @IBOutlet weak var bodySensorLocationLabel: UILabel!
  
  var centralManager: CBCentralManager!
  var heartRatePeripheral: CBPeripheral!
  
  let heartRateServiceCBUUID = CBUUID(string: "0x180D")
  
  let heartRateMeasurementCharacteristicCBUUID = CBUUID(string: "2A37")
  let bodySensorLocationCharacteristicCBUUID = CBUUID(string: "2A38")
  
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    // Make the digits monospaces to avoid shifting when the numbers change
    heartRateLabel.font = UIFont.monospacedDigitSystemFont(ofSize: heartRateLabel.font!.pointSize, weight: .regular)
    
    // MARK: - 1) Initialize Central Manager, it represents the iOS device
    // This will call centralManagerDidUpdateState delegate method
    centralManager = CBCentralManager(delegate: self, queue: nil)
  }
  
  func onHeartRateReceived(_ heartRate: Int) {
    heartRateLabel.text = String(heartRate)
    print("BPM: \(heartRate)")
  }
}


extension HRMViewController: CBCentralManagerDelegate {
  
  func centralManagerDidUpdateState(_ central: CBCentralManager) {
    
    switch central.state {
    case .unknown:
      print("central.state is .unknown")
    case .resetting:
      print("central.state is .resetting")
    case .unsupported:
      print("central.state is .unsupported")
    case .unauthorized:
      print("central.state is .unauthorized")
    case .poweredOff:
      print("central.state is .poweredOff")
      
    case .poweredOn:
      print("central.state is .poweredOn")
      // MARK: - 2) Start scanning for Peripherals
      // Here we are specifically looking for peripherals with Heart Rate service
      // We can change the UUID to look for peripherals with other services
      // Or we can set it to nil and get all peripherals around
      // This will call didDiscover delegate method
      centralManager.scanForPeripherals(withServices: [heartRateServiceCBUUID])
    }
  }
  
  // MARK: - 3) Here we get a reference to the peripheral
  // Now we stop scanning other for other peripherals
  // And connect centralManager to heartRatePeripheral
  // This will call didConnect delegate method
  func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
    print("found peripheral: \(peripheral)")
    heartRatePeripheral = peripheral
    heartRatePeripheral.delegate = self
    centralManager.stopScan()
    centralManager.connect(heartRatePeripheral)
  }
  
  // MARK: - 4) Here the iOS device as a central and the Heart Rate sensor as a peripheral are connected
  // Now we discover the Heart Rate Service in the Peripheral
  // We can discover all available services by setting the array to nil
  // This will call didDiscoverServices delegate method
  func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
    print("Connected!")
    heartRatePeripheral.discoverServices([heartRateServiceCBUUID])
  }
}

extension HRMViewController: CBPeripheralDelegate {
  
  // MARK: - 5) Here we get an array that has one element which is Hate Rate service
  // Now we discover all characteristics in the Hate Rate service
  // This will call didDiscoverCharacteristicsFor delegate method
  func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
    
    guard let services = peripheral.services else { return }
    
    for service in services {
      print(service)
      print(service.characteristics ?? "characteristics are nil")
      peripheral.discoverCharacteristics(nil, for: service)
    }
  }
  
  
  // MARK: - 6) Here we get 2 Characteristics:
  // 1. Body Location Characteristic: has read property for one time read
  // 2. Heart Rate Measurement Characteristic: has notify property, to notify the iOS device every time the heart rate changes
  // Now we read the value of each characteristic
  // This will update didUpdateValueFor delegate method
  func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
    
    guard let characteristics = service.characteristics else { return }
    
    for characteristic in characteristics {
      print(characteristic)
      
      // Body Location Characteristic
      if characteristic.properties.contains(.read) {
        print("\(characteristic.uuid): properties contains .read")
        peripheral.readValue(for: characteristic)
      }
      
      // Heart Rate Measurement Characteristic
      if characteristic.properties.contains(.notify) {
        print("\(characteristic.uuid): properties contains .notify")
        peripheral.setNotifyValue(true, for: characteristic)
      }
      
    }
  }
  
  
  // MARK: - 7) Here we get the value of the Body Location one time & the value of Heart Rate every notification
  // So we read the characteristic value and show it on the corresponding Label
  func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic,
                  error: Error?) {
    print("characteristic: \(characteristic)")
    switch characteristic.uuid {
    case bodySensorLocationCharacteristicCBUUID:
      let bodySensorLocation = bodyLocation(from: characteristic)
      bodySensorLocationLabel.text = bodySensorLocation
    case heartRateMeasurementCharacteristicCBUUID:
      let bpm = heartRate(from: characteristic)
      onHeartRateReceived(bpm)
    default:
      print("Unhandled Characteristic UUID: \(characteristic.uuid)")
    }
  }
}


// MARK: - Helper Functions
extension HRMViewController {
  private func bodyLocation(from characteristic: CBCharacteristic) -> String {
    guard let characteristicData = characteristic.value,
          let byte = characteristicData.first else { return "Error" }
    
    switch byte {
    case 0: return "Other"
    case 1: return "Chest"
    case 2: return "Wrist"
    case 3: return "Finger"
    case 4: return "Hand"
    case 5: return "Ear Lobe"
    case 6: return "Foot"
    default:
      return "Reserved for future use"
    }
  }
  
  private func heartRate(from characteristic: CBCharacteristic) -> Int {
    guard let characteristicData = characteristic.value else { return -1 }
    let byteArray = [UInt8](characteristicData)
    
    let firstBitValue = byteArray[0] & 0x01
    if firstBitValue == 0 {
      // Heart Rate Value Format is in the 2nd byte
      return Int(byteArray[1])
    } else {
      // Heart Rate Value Format is in the 2nd and 3rd bytes
      return (Int(byteArray[1]) << 8) + Int(byteArray[2])
    }
  }
}
