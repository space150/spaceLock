//
//  SLLockListViewController.swift
//  spacelab
//
//  Created by Shawn Roske on 3/20/15.
//  Copyright (c) 2015 space150. All rights reserved.
//

import UIKit

class SLLockViewController: UIViewController,
    UITableViewDelegate,
    UITableViewDataSource,
    RFduinoManagerDelegate,
    RFduinoDelegate
{
    @IBOutlet weak var tableView: UITableView!
    
    private var rfduinoManager : RFduinoManager!
    private var connectedRfduino : RFduino!
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        //tableView.registerClass(SLLockViewCell.self, forCellReuseIdentifier: "cell")
        
        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.estimatedRowHeight = 160.0
        
        rfduinoManager = RFduinoManager.sharedRFduinoManager()
        rfduinoManager.delegate = self
        
        var security = SLSecurityManager()
        var hello = "s150-msp-f3"
        var data : NSData = security.encryptString(hello)
        println("hello: \(data.hexadecimalString())")
    }
    
    override func didReceiveMemoryWarning()
    {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: - UITableViewDataSource Methods
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int
    {
        return rfduinoManager.rfduinos.count
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell
    {
        var cell:SLLockViewCell = self.tableView.dequeueReusableCellWithIdentifier("cell") as SLLockViewCell
        
        var rfduino = rfduinoManager.rfduinos.objectAtIndex(indexPath.row) as RFduino
        
        var rssi = rfduino.advertisementRSSI.intValue;
        
        var advertising = "";
        if ( rfduino.advertisementData != nil ) {
            advertising = NSString(data: rfduino.advertisementData, encoding: NSUTF8StringEncoding)!
        }
        
        var detail : NSMutableString = NSMutableString(capacity: 100)
        detail.appendFormat("RSSI: %d dBm", rssi);
        while ( detail.length < 25 ) {
            detail.appendString(" ")
        }
        detail.appendFormat("Packets: %d\n", rfduino.advertisementPackets)
        detail.appendFormat("%@", advertising)
        
        cell.titleLabel?.text = rfduino.name
        cell.subtitleLabel?.text = detail
        
        if ( rfduino.outOfRange == 0 ) {
            cell.titleLabel?.textColor = UIColor.blackColor()
            cell.subtitleLabel?.textColor = UIColor.blackColor()
        } else {
            cell.titleLabel?.textColor = UIColor.grayColor()
            cell.subtitleLabel?.textColor = UIColor.grayColor()
        }
        
        return cell
    }
    
    // MARK: - UITableViewDelegate Methods
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath)
    {
        var rfduino = rfduinoManager.rfduinos.objectAtIndex(indexPath.row) as RFduino
        println("rfduino.outOfRange: \(rfduino.outOfRange)")
        if ( rfduino.outOfRange == 0 ) {
            rfduinoManager.connectRFduino(rfduino)
        }
    }
    
    // MARK: - RFduino Manager Delegate Methods
    
    func didDiscoverRFduino(rfduino: RFduino!)
    {
        //println("didDiscoverRFDuino: \(rfduino)")
        tableView.reloadData()
    }
    
    func didUpdateDiscoveredRFduino(rfduino: RFduino!)
    {
        //println("didUpdateDiscoveredRFduino: \(rfduino)")
        tableView.reloadData()
    }
    
    func didLoadServiceRFduino(rfduino: RFduino!)
    {
        println("didLoadServiceRFduino: \(rfduino)")
    }
    
    func didConnectRFduino(rfduino: RFduino!)
    {
        println("didConnectRFduino: \(rfduino)")
        
        rfduinoManager.stopScan()
        
        connectedRfduino = rfduino
        rfduino.delegate = self
    }
    
    func didDisconnectRFduino(rfduino: RFduino!)
    {
        println("didDisconnectRFduino: \(rfduino)")
        
        if ( connectedRfduino != nil )
        {
            connectedRfduino.delegate = nil
        }
        
        rfduinoManager.startScan()
    }
    
    // MARK: - RFduino Delegate Methods
    
    func didReceive(data: NSData!)
    {
        println("received data: \(data)")
        
        if ( data.length == 16 )
        {
            // we got a handshake, descrypt it!
            var security = SLSecurityManager()
            var lockId : NSString = security.decryptData(data)
            println("lockId: \(lockId)")
            
            var command = NSString(format: "%@%d", "u", Int(NSDate().timeIntervalSince1970))
            var data : NSData = security.encryptString(command)
            
            connectedRfduino.send(data)
            
            // force disconnection, in the future we could listen for the lock status and disconnect later?
            connectedRfduino.disconnect()
        }
    }
    
}