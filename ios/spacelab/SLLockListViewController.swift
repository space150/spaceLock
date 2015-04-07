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
    GPPSignInDelegate,
    SLLockViewCellDelegate
{
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var headerNameLabel: UILabel!
    @IBOutlet weak var headerImageView: UIImageView!
    @IBOutlet weak var logoutButton: UIButton!
    @IBOutlet weak var lockCountHeaderLabel: UILabel!
    
    private var fetchedResultsController: NSFetchedResultsController!
    
    private var discoveryManager: LKLockDiscoveryManager!
    
    private let clientId = "743774015347-4qc7he8nbpccqca59lh004ojr7a94kia.apps.googleusercontent.com";
    private var signIn : GPPSignIn?
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        configureGooglePlus()
        
        discoveryManager = LKLockDiscoveryManager(context: "ios-client")
        
        fetchedResultsController = getFetchedResultsController()
        fetchedResultsController.delegate = self
        fetchedResultsController.performFetch(nil)
        
        view.backgroundColor = UIColor(patternImage: UIImage(named: "background-normal.png")!)
        tableView.backgroundColor = UIColor.clearColor()
        logoutButton.titleLabel?.font = UIFont(name: "DINCondensed-Bold", size: 20)
        lockCountHeaderLabel.font = UIFont(name: "DINPro-CondLight", size: 46)
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
        
        //discoveryManager.stopDiscovery()
        
        UIApplication.sharedApplication().setStatusBarStyle(UIStatusBarStyle.BlackOpaque, animated: true)
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
        cell.delegate = self
        cell.setLock(lock, indexPath: indexPath)
    }
    
    // MARK: - SLLockViewCellDelegate methods
    
    func performUnlock(indexPath: NSIndexPath)
    {
        let lock: LKLock = fetchedResultsController.objectAtIndexPath(indexPath) as LKLock
        let cell: SLLockViewCell = self.tableView.cellForRowAtIndexPath(indexPath) as SLLockViewCell

        cell.showInProgress()
        
        self.discoveryManager.openLock(lock, complete: { (success, error) -> Void in
            if ( success )
            {
                cell.showUnlocked()
            }
            else
            {
                println("ERROR opening lock: \(error.localizedDescription)")

                cell.resetUnlocked()
            }
        })
        
        tableView.deselectRowAtIndexPath(indexPath, animated: true)
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
        lockCountHeaderLabel.text = NSString(format: "LOCKS (%d)", fetchedResultsController.sections![0].numberOfObjects)
        self.tableView.endUpdates()
    }
    
    // MARK: - UITableViewDelegate Methods
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath)
    {
        // nothing, deprecated!
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

            // if the login view controller is showing, hide it
            dismissViewControllerAnimated(true, completion: { () -> Void in
                // nothing
            })
        }
        else
        {
            // clear out the header info
            headerNameLabel.text = "Unknown"
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