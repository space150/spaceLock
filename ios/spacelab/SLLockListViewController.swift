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
    NSFetchedResultsControllerDelegate,
    GPPSignInDelegate
{
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var headerNameLabel: UILabel!
    @IBOutlet weak var headerEmailLabel: UILabel!
    @IBOutlet weak var headerImageView: UIImageView!
    
    private var fetchedResultsController: NSFetchedResultsController!
    
    private var HUD: MBProgressHUD!
    private var HUDImageView: UIImageView!
    
    private var discoveryManager: LKLockDiscoveryManager!
    
    private let clientId = "743774015347-4qc7he8nbpccqca59lh004ojr7a94kia.apps.googleusercontent.com";
    private var signIn : GPPSignIn?
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.estimatedRowHeight = 120.0
        
        configureGooglePlus()
        
        discoveryManager = LKLockDiscoveryManager()
        
        fetchedResultsController = getFetchedResultsController()
        fetchedResultsController.delegate = self
        fetchedResultsController.performFetch(nil)
        
        HUD = MBProgressHUD(view: view)
        view.addSubview(HUD)
        
        HUDImageView = UIImageView(image: UIImage(named: "37x-Checkmark.png"))
    }
    
    override func viewDidAppear(animated: Bool)
    {
        super.viewDidAppear(animated)
        
        var success: Bool? = signIn?.trySilentAuthentication()
        if ( success == false )
        {
            performSegueWithIdentifier("showLogin", sender: self)
        }
        
        discoveryManager.startDiscovery()
    }
    
    override func viewWillDisappear(animated: Bool)
    {
        super.viewWillDisappear(animated)
        
        discoveryManager.stopDiscovery()
    }
    
    override func didReceiveMemoryWarning()
    {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: - UITableViewDataSource Methods
    
    func numberOfSectionsInTableView(tableView: UITableView!) -> Int
    {
        return fetchedResultsController.sections!.count
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int
    {
        return fetchedResultsController.sections![section].numberOfObjects
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell
    {
        var cell:SLLockViewCell = self.tableView.dequeueReusableCellWithIdentifier("cell") as SLLockViewCell
        configureCell(cell, atIndexPath: indexPath)
        return cell
    }
    
    func configureCell(cell: SLLockViewCell, atIndexPath indexPath: NSIndexPath)
    {
        let lock: LKLock = fetchedResultsController.objectAtIndexPath(indexPath) as LKLock
        cell.titleLabel.text = lock.name
        cell.subtitleLabel.text = NSString(format: "uuid: %@\nproximity: %@", lock.uuid, lock.proximityString)
    }
    
    // MARK: - NSFetchedResultsController methods
    
    func getFetchedResultsController() -> NSFetchedResultsController
    {
        let fetchedResultsController = NSFetchedResultsController(fetchRequest: taskFetchRequest(), managedObjectContext: LKLockRepository.sharedInstance().managedObjectContext,
            sectionNameKeyPath: nil, cacheName: nil)
        return fetchedResultsController
    }
    
    func taskFetchRequest() -> NSFetchRequest
    {
        let fetchRequest = NSFetchRequest(entityName: "LKLock")
        let sortDescriptor = NSSortDescriptor(key: "proximity", ascending: false)
        fetchRequest.sortDescriptors = [sortDescriptor]
        return fetchRequest
    }
    
    func controllerWillChangeContent(controller: NSFetchedResultsController)
    {
        self.tableView.beginUpdates()
    }

    func controller(controller: NSFetchedResultsController, didChangeObject object: AnyObject, atIndexPath indexPath: NSIndexPath,
        forChangeType type: NSFetchedResultsChangeType, newIndexPath: NSIndexPath)
    {
            switch type
            {
            case .Insert:
                self.tableView.insertRowsAtIndexPaths([newIndexPath], withRowAnimation: .Fade)
            case .Update:
                let cell: SLLockViewCell = self.tableView.cellForRowAtIndexPath(indexPath) as SLLockViewCell
                self.configureCell(cell, atIndexPath: indexPath)
                self.tableView.reloadRowsAtIndexPaths([indexPath], withRowAnimation: .Fade)
            case .Move:
                self.tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Fade)
                self.tableView.insertRowsAtIndexPaths([newIndexPath], withRowAnimation: .Fade)
            case .Delete:
                self.tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Fade)
            default:
                return
            }
    }

    func controllerDidChangeContent(controller: NSFetchedResultsController)
    {
        self.tableView.endUpdates()
    }
    
    // MARK: - UITableViewDelegate Methods
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath)
    {
        let lock: LKLock = fetchedResultsController.objectAtIndexPath(indexPath) as LKLock
        
        HUD.mode = .Indeterminate
        HUD.labelText = "Unlocking"
        HUD.show(true)

        self.discoveryManager.openLock(lock, complete: { (success, error) -> Void in
            if ( success )
            {
                self.HUD.customView = self.HUDImageView
                self.HUD.mode = .CustomView
                self.HUD.labelText = "UNLOCKED"
                
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(2.0 * Double(NSEC_PER_SEC))), dispatch_get_main_queue()) { () -> Void in
                    self.HUD.hide(true)
                }
            }
            else
            {
                println("ERROR opening lock: \(error.localizedDescription)")
                
                self.HUD.mode = .Text
                self.HUD.labelText = "Error opening lock!"
                
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(2.0 * Double(NSEC_PER_SEC))), dispatch_get_main_queue()) { () -> Void in
                    self.HUD.hide(true)
                }
            }
        })

        tableView.deselectRowAtIndexPath(indexPath, animated: true)
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