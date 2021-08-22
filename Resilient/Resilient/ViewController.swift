//
//  ViewController.swift
//  Resilient
//
//  Created by Brookelle Mathieson on 8/1/21.
//

import UIKit
import Charts
import CoreBluetooth
import Foundation


var curPeripheral: CBPeripheral?
var txCharacteristic: CBCharacteristic?
var rxCharacteristic: CBCharacteristic?


class ViewController: UIViewController, CBCentralManagerDelegate, CBPeripheralDelegate {
    
    
    
    //Variable Initializations
    var centralManager: CBCentralManager!
    //var data = NSMutableData ()
    var rssiList = [NSNumber]()
    var peripheralList: [CBPeripheral] = []
    var characteristicList = [String: CBCharacteristic]()
    var characteristicValue = [CBUUID: NSData]()
    var timer = Timer()
    
    let BLE_Service_UUID = CBUUID.init(string: "6e400001-b5a3-f393-e0a9-e50e24dcca9e")
    let BLE_Characteristic_uuid_Rx = CBUUID.init(string: "6e400003-b5a3-f393-e0a9-e50e24dcca9e")
    let BLE_Characteristic_uuid_Tx = CBUUID.init(string: "6e400002-b5a3-f393-e0a9-e50e24dcca9e")
    
    var recievedData = [Int]()
    var showGraphIsOn = true

    @IBOutlet weak var lineChartBox: LineChartView!
    
    @IBOutlet weak var showGraphLbl: UILabel!
    @IBOutlet weak var connectStatusLbl: UILabel!
    
    @IBAction func showGraphBtn(_ sender: Any) {
    }
    @IBAction func refreshBtn(_ sender: Any) {
    }
    
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        connectStatusLbl.text = "Disconnected"
        connectStatusLbl.textColor = UIColor.red
        
        centralManager = CBCentralManager (delegate: self, queue: nil)
        // Do any additional setup after loading the view.
       // let data = [3, 4, 5, 6, 8, 5]
       // graphLineChart (dataArray: data)
    }
    
    override func viewDidAppear(_ animated: Bool){
        super.viewDidAppear(animated)
        
        if curPeripheral != nil {
            centralManager?.cancelPeripheralConnection(curPeripheral!)
            
        }
        print("View Cleared")
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        print("Stop Scanning")
        
        centralManager?.stopScan()
    }
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        
        if central.state == CBManagerState.poweredOn {
            print("Bluetooth Enabled")
            startScan()
        }
        else {
            print("Bluetooth Disabled - Make sure your Bluetooth is turned on")
            
            let alertVC = UIAlertController(title: "Bluetooth is not enabled",
                                            message: "make sure your Bluetooth is turned on",
                                            preferredStyle: UIAlertController.Style.alert)
            
            let action = UIAlertAction(title: "ok",
                                       style: UIAlertAction.Style.default,
                                       handler:{ (action: UIAlertAction) -> Void in self.dismiss(animated: true, completion: nil)
                                       })
            alertVC.addAction(action)
            self.present(alertVC, animated: true, completion: nil)
            
        }
    }
    
    func startScan() {
        print("Now Scanning...")
        print("Serve ID Search: \(BLE_Service_UUID)")
    
    peripheralList = []
    
    self.timer.invalidate()
    
    centralManager?.scanForPeripherals(withServices: [BLE_Service_UUID],
    options: [CBCentralManagerScanOptionAllowDuplicatesKey:false])
    Timer.scheduledTimer(withTimeInterval: 10, repeats: false) {_ in self.cancelScan()
    
        }
    }

func cancelScan() {
    self.centralManager?.stopScan()
    print("Scan Stopped")
    print("Number of Peripherals Found: \(peripheralList.count)")
}
func centralManager(_ central:CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String : Any],
                        rssi RSSI: NSNumber) {
        
        curPeripheral = peripheral
        self.peripheralList.append(peripheral)
        self.rssiList.append(RSSI)
        peripheral.delegate = self
        
        if curPeripheral != nil {
            centralManager?.connect(curPeripheral!, options: nil)
        }
    }
    
    func restoreCentralManager() {
        centralManager?.delegate = self
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("-------------------------------------------------")
        print("Connection complete")
        print("Peripheral info: \(String(describing: curPeripheral))")
        
        cancelScan()
        
        peripheral.delegate = self
        
        peripheral.discoverServices([BLE_Service_UUID])
        
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        
        if error != nil {
            print("Failed to connect to peripheral")
            return
        }
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("Disconnected")
        connectStatusLbl.text = "Disconnected"
        connectStatusLbl.textColor = UIColor.red
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        print("-------------------------------------------------")
        
        if ((error) != nil) {
            print("Error discovering services: \(error!.localizedDescription)")
            return
        }
        guard let services = peripheral.services else {
            return
        }
        
        print("Discovered Services: \(services)")
        
        for service in services {
            if service.uuid == BLE_Service_UUID {
                print("Service found")
                connectStatusLbl.text = "Connected!"
                connectStatusLbl.textColor = UIColor.blue
                
                peripheral.discoverCharacteristics(nil, for: service)
            }
        }
    }
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        print("-------------------------------------------")
        
        if ((error) != nil) {
            print("Error discovering services: \(error!.localizedDescription)")
            return
        }

        guard let characteristics = service.characteristics else {
            return
        }
    
        print("Found \(characteristics.count) characteristics!")
        
        for characteristic in characteristics {
            
            if characteristic.uuid.isEqual(BLE_Characteristic_uuid_Rx) {
                rxCharacteristic = characteristic
                
                peripheral.setNotifyValue(true, for: rxCharacteristic!)
                peripheral.readValue(for: characteristic)
                print("Rx Characteristic: \(characteristic.uuid)")
            }
            
            if characteristic.uuid.isEqual(BLE_Characteristic_uuid_Tx){
                txCharacteristic = characteristic
                print("Tx Characteristic: \(characteristic.uuid)")
            }
            peripheral.discoverDescriptors(for:characteristic)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
     print("************************************************")
        
        if (error != nil) {
            print("Error changing notification state:\(String(describing: error?.localizedDescription))")
        } else {
            print("Characteristic's value subscribed")
        }
        
        if (characteristic.isNotifying) {
            print ("Subscribed. Notification has begun for: \(characteristic.uuid)")
        }
    
    }
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristc: CBCharacteristic, error: Error?) {
        
        guard characteristic == rxCharacteristic,
        let characteristicValue = characteristic.value,
        let recievedString = NSString(data: characteristicValue, encoding: String.Encoding.utf8.rawValue)
        else { return }
        
        for i in 0..<recievedString.length {
            
            print(recievedString.character(at: i))
            let number:Int = Int(recievedString.character(at: i))
            recievedData.append(number)
        }
        
        if (recievedData.count > 100) {
            recievedData.removeFirst(recievedData.count-100)
        }
        if (showGraphIsOn && recievedData.count > 0) {
            showGrap(dataDisplaying: recievedData)
        }
        NotificationCenter.default.post(name:NSNotification.Name(rawValue: "Notify"), object: self)
    }
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?){
        guard error == nil else {
            print("Error discovering services: error")
            return
        }
        print("Message sent")
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverDescriptorsFor characteristic: CBCharacteristic, error: Error?) {
        
        print("*******************************************")
        if error != nil {
            print("\(error.debugDescription)")
            return
        }
        guard let descriptors = characteristic.descriptors else { return }
        
        descriptors.forEach { descript in
            print("function name: DidDiscoverDescriptorForChar \(String(describing: descript.description))")
            print("Rx Value \(String(describing: rxCharacteristic?.value))")
            print("Tx Value \(String(describing: txCharacteristic?.value))")
        }

    }
}
