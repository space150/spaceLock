//
//  SLLockListViewController.swift
//  spacelab
//
//  Created by Shawn Roske on 3/20/15.
//  Copyright (c) 2015 space150. All rights reserved.
//

import UIKit
import LockKit

class SLLockViewController: UIViewController,
    UITableViewDelegate,
    UITableViewDataSource,
    RFduinoManagerDelegate,
    RFduinoDelegate,
    GPPSignInDelegate
{
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var headerNameLabel: UILabel!
    @IBOutlet weak var headerEmailLabel: UILabel!
    @IBOutlet weak var headerImageView: UIImageView!
    
    private var rfduinoManager : RFduinoManager!
    private var connectedRfduino : RFduino!
    
    private let clientId = "743774015347-4qc7he8nbpccqca59lh004ojr7a94kia.apps.googleusercontent.com";
    private var signIn : GPPSignIn?
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.estimatedRowHeight = 120.0
        
        rfduinoManager = RFduinoManager.sharedRFduinoManager()
        rfduinoManager.delegate = self
        
        configureGooglePlus()
        
        var repo = LKLockRepository()
    }
    
    override func viewDidAppear(animated: Bool)
    {
        super.viewDidAppear(animated)
        
        var success: Bool? = signIn?.trySilentAuthentication()
        if ( success == false )
        {
            performSegueWithIdentifier("showLogin", sender: self)
        }
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
        initHandshake(rfduino)
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
        
        verifyHandshake(data)
    }
    
    // MARK: - Security methods
    
    func initHandshake(rfduino: RFduino!)
    {
        var backgroundQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)
        dispatch_async(backgroundQueue, { () -> Void in
            if ( rfduino.outOfRange == 0 ) {
                self.rfduinoManager.connectRFduino(rfduino)
            }
        })
    }
    
    func verifyHandshake(data: NSData!)
    {
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
    
    // MARK: - GPPSignInDelegate Methods
    
    func configureGooglePlus()
    {
        signIn = GPPSignIn.sharedInstance()
        signIn?.clientID = clientId
        
        signIn?.shouldFetchGooglePlusUser = true
        signIn?.shouldFetchGoogleUserID = true
        signIn?.shouldFetchGoogleUserEmail = true
        
        signIn?.scopes = [ kGTLAuthScopePlusLogin ];  // "https://www.googleapis.com/auth/plus.login" scope
        //signIn.scopes = @[ @"profile" ];            // "profile" scope

        signIn?.delegate = self;
    }
    
    @IBAction func doLogout(sender: AnyObject)
    {
        signIn?.signOut()
        checkAuthState()
    }
    
    func finishedWithAuth(auth: GTMOAuth2Authentication!, error: NSError!)
    {
        if ( error != nil )
        {
            println("google+ connect failure - finishedWithAuth: \(error.localizedDescription)")
        }
        
        checkAuthState()
    }
    
    func didDisconnectWithError(error: NSError!)
    {
        if ( error != nil )
        {
            println("google+ connect failure - didDisconnectWithError: \(error.localizedDescription)")
        }
        
        checkAuthState()
    }
    
    func checkAuthState()
    {
        if ( signIn?.authentication != nil )
        {
            var email = signIn?.authentication.userEmail
            
            // check to ensure the email is on the space150.com domain!
            if ( validateEmail(email) == false )
            {
                signIn?.signOut()
            }
        }
        
        if ( signIn?.authentication != nil )
        {
            // if we have a google plus user object
            var plusUser: GTLPlusPerson! = signIn?.googlePlusUser
            if ( plusUser != nil )
            {
                // use the display name
                headerNameLabel.text = plusUser.displayName
                
                // and avatar image
                var backgroundQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)
                dispatch_async(backgroundQueue, { () -> Void in
                    if ( plusUser?.image.url != nil )
                    {
                        var avatarUrl = NSURL(string: plusUser.image.url)!
                        var avatarData = NSData(contentsOfURL: avatarUrl)
                        if ( avatarData != nil )
                        {
                            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                                self.headerImageView.image = UIImage(data: avatarData!)
                            })
                        }
                        
                    }
                })
            }
            else
            {
                // otherwise clear out the existing info
                headerNameLabel.text = "Unknown"
                headerImageView.image = nil
            }
            
            headerEmailLabel.text = signIn?.authentication.userEmail
            
            // if the login view controller is showing, hide it
            dismissViewControllerAnimated(true, completion: { () -> Void in
                // nothing
            })
        }
        else
        {
            // clear out the header info
            headerNameLabel.text = ""
            headerEmailLabel.text = ""
            headerImageView.image = nil
            
            // present the login view controller
            performSegueWithIdentifier("showLogin", sender: self)
        }
    }
    
    func validateEmail(email: NSString!) -> Bool
    {
        var predicate = NSPredicate(format: "SELF MATCHES %@", "[A-Z0-9a-z\\._%+-]+@space150.com")!
        return predicate.evaluateWithObject(email)
    }

}