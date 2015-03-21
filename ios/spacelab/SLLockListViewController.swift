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
    RFduinoManagerDelegate
{
    @IBOutlet weak var tableView: UITableView!
    
    private var rfduinoManager : RFduinoManager!
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        tableView.registerClass(UITableViewCell.self, forCellReuseIdentifier: "cell")
        
        rfduinoManager = RFduinoManager.sharedRFduinoManager()
        rfduinoManager.delegate = self
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
        var cell:UITableViewCell = self.tableView.dequeueReusableCellWithIdentifier("cell") as UITableViewCell
        
        var rfduino = rfduinoManager.rfduinos.objectAtIndex(indexPath.row) as RFduino
        
        var uuid = rfduino.UUID
        
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
        detail.appendFormat("Advertising: %@\n", advertising)
        detail.appendFormat("%@", uuid)
        
        cell.textLabel?.text = rfduino.name
        cell.detailTextLabel?.text = detail
        cell.detailTextLabel?.numberOfLines = 3
        
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
    
    // MARK: - RFduino Delegate Methods
    
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
        
        var security = SLSecurityManager()
        var data : NSData = security.encryptString("Swifthello!");
        println("data: \(data)")
        
        rfduino.send(data)
        
        rfduino.disconnect()
    }
    
    func didConnectRFduino(rfduino: RFduino!)
    {
        println("didConnectRFduino: \(rfduino)")
        
        rfduinoManager.stopScan()
    }
    
    func didDisconnectRFduino(rfduino: RFduino!)
    {
        println("didDisconnectRFduino: \(rfduino)")
        
        rfduinoManager.startScan()
    }
    
}