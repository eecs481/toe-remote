//
//  DeviceViewController.swift
//  toe-remote
//


import UIKit
import CoreBluetooth

class DeviceViewController: UIViewController, BLEDelegate {
    var ble: BLE?
    var peripheral: CBPeripheral
    var buttonLayout: ButtonLayout?
    var readBuffer: NSMutableData
    var index: Int
    var numButtons: UInt8?
    var buttonView: UIView?
    var selectionViewController: SelectionViewController?
    var viewLoaded: Bool
    var paused: Bool
    
    init(selectionViewController: SelectionViewController?, ble: BLE?, peripheral: CBPeripheral) {
        self.selectionViewController = selectionViewController
        self.ble = ble
        self.peripheral = peripheral
        self.buttonLayout = selectionViewController?.cachedLayouts[peripheral.identifier.UUIDString]
        self.readBuffer = NSMutableData()
        self.index = 0
        self.viewLoaded = false
        self.paused = false
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("Method not implemented")
    }
    
    override func viewDidLoad() {
        self.view.backgroundColor = UIColor.whiteColor()
        addTitleView(self.view)
        let titleHeight = self.view.bounds.height / 10.0
        self.buttonView = UIView(frame: CGRectMake(0, titleHeight, self.view.bounds.width, titleHeight * 9.0))
        view.addSubview(buttonView!)
        if buttonLayout != nil {
            buttonLayout!.addToView(buttonView!)
        }
        viewLoaded = true
    }
    
    func saveLayout() {
        guard let buttonLayout = buttonLayout else { return }
        let key = peripheral.identifier.UUIDString
        selectionViewController?.cachedLayouts.updateValue(buttonLayout, forKey: key)
    }
    
    func popView() {
        self.dismissViewControllerAnimated(true, completion: {();
            guard let selectionViewController = self.selectionViewController else { return }
            self.ble?.delegate = selectionViewController
            self.ble?.disconnectFromPeripheral(self.peripheral)
            selectionViewController.deviceViewController = nil
            selectionViewController.retrieveNearbyDevices()
        })
    }
    
    func selectButtonToEdit() {
        
    }
    
    func startEditing() {
        buttonLayout?.setTargetAction(self, action: Selector("selectButtonToEdit"))
    }
    
    func finishEditing() {
        buttonLayout?.setTargetAction(nil, action: nil)
    }
    
    func addTitleView(view: UIView) {
        let titleBar = UIView(frame: CGRectMake(0, 0, view.bounds.width, view.bounds.height / 10))
        let backButtonWidth: CGFloat = 100.0
        
        let title = UILabel(frame: CGRectMake(backButtonWidth, 0, titleBar.bounds.width - 2*backButtonWidth, titleBar.bounds.size.height))
        title.text = ble?.getName(peripheral)
        if title.text == nil {
            title.text = peripheral.name
        }
        title.textAlignment = .Center
        titleBar.addSubview(title)
        
        let backButton = UIButton(frame: CGRectMake(0, 0, backButtonWidth, titleBar.bounds.size.height))
        backButton.setTitle("Back", forState: .Normal)
        backButton.setTitleColor(UIColor.blueColor(), forState: .Normal)
        if selectionViewController != nil {
            backButton.addTarget(self, action: Selector("popView"), forControlEvents: .TouchUpInside)
        }
        titleBar.addSubview(backButton)
        
        let editButton = UIButton(frame: CGRectMake(titleBar.bounds.width - backButtonWidth, 0, backButtonWidth, titleBar.bounds.size.height))
        editButton.setTitle("Edit", forState: .Normal)
        editButton.setTitleColor(UIColor.blueColor(), forState: .Normal)
        if selectionViewController != nil {
            editButton.addTarget(self, action: Selector("edit"), forControlEvents: .TouchUpInside)
        }
        titleBar.addSubview(editButton)
        
        view.addSubview(titleBar)
    }
    
    func bleDidScanTimeout() { }
    
    func bleDidUpdateState(state: CBCentralManagerState) {
        if state == .PoweredOn {
            if !paused {
                ble?.connectToPeripheral(peripheral)
            }
        }
    }
    
    func bleDidConnectToPeripheral() {
        print("[DEBUG] Connected to peripheral")
        if buttonLayout == nil {
            ble?.enableNotifications(true)
            print("[DEBUG] Sending Button Layout Request")
            buttonLayout = ButtonLayout()
            let bytes: [UInt8] = [0x00, 0x00]
            ble?.write(data: NSData(bytes: bytes, length: 2))
        }
    }
    
    func bleDidDisconenctFromPeripheral() {
        print("[DEBUG] Disconnected from peripheral")
        if !paused {
            ble?.connectToPeripheral(peripheral)
        }
    }
    
    func bleDidReceiveData(data: NSData?) {
        guard let buttonLayout = buttonLayout else { return }
        guard let data = data else { return }
        readBuffer.appendData(data)
        guard readBuffer.length - index > 0 else { return }
        if numButtons == nil {
            numButtons = UnsafePointer<UInt8>(readBuffer.bytes).memory
            ++index
        }
        guard let ble = ble else { return }
        while numButtons > 0 && readBuffer.length - index >= 55 {
            let range = NSRange(location: index, length: 55)
            let active = selectionViewController != nil
            buttonLayout.addButton(ble, data: readBuffer.subdataWithRange(range), active: active)
            index += 55
            --numButtons!
        }
        if numButtons == 0 {
            print("[DEBUG] Recieved the layout")
            // ble.enableNotifications(false)
            saveLayout()
            if self.viewLoaded {
                buttonLayout.addToView(buttonView!)
            }
        }
    }
    
    func resume() {
        paused = false
        ble?.connectToPeripheral(peripheral)
    }
    
    func pause() {
        paused = true
    }
    
}