//
//  SLLockListViewController.swift
//  spacelab
//
//  Created by Shawn Roske on 3/20/15.
//  Copyright (c) 2015 space150, Inc.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy of this software and
//  associated documentation files (the "Software"), to deal in the Software without restriction, including
//  without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the
//  following conditions:
//
//  The above copyright notice and this permission notice shall be included in all copies or substantial
//  portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT
//  LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO
//  EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
//  IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR
//  THE USE OR OTHER DEALINGS IN THE SOFTWARE.
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
    
    fileprivate var fetchedResultsController: NSFetchedResultsController<NSFetchRequestResult>!
    
    fileprivate var discoveryManager: LKLockDiscoveryManager!
    fileprivate var unlocking:Bool!
    
    fileprivate let clientId = "743774015347-4qc7he8nbpccqca59lh004ojr7a94kia.apps.googleusercontent.com";
    fileprivate var signIn : GPPSignIn?
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        configureGooglePlus()
        
        discoveryManager = LKLockDiscoveryManager(context: "ios-client")
        
        unlocking = false
        
        fetchedResultsController = getFetchedResultsController()
        fetchedResultsController.delegate = self
        try! fetchedResultsController.performFetch()
    }
    
    override func viewDidAppear(_ animated: Bool)
    {
        super.viewDidAppear(animated)
        
        let success: Bool? = signIn?.trySilentAuthentication()
        if ( success == false )
        {
            performSegue(withIdentifier: "showLogin", sender: self)
        }
        else
        {
            discoveryManager.startDiscovery()
        }
        
        let security = LKSecurityManager()
        security.generateKey(forLockName: "s150-vip")
    }
    
    override func viewWillDisappear(_ animated: Bool)
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
    
    func numberOfSections(in tableView: UITableView) -> Int
    {
        return fetchedResultsController.sections!.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int
    {
        return fetchedResultsController.sections![section].numberOfObjects
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell
    {
        let cell:SLLockViewCell = self.tableView.dequeueReusableCell(withIdentifier: "cell") as! SLLockViewCell
        configureCell(cell, atIndexPath: indexPath)
        return cell
    }
    
    func configureCell(_ cell: SLLockViewCell, atIndexPath indexPath: IndexPath)
    {
        let lock: LKLock = fetchedResultsController.object(at: indexPath) as! LKLock
        cell.delegate = self
        cell.setLock(lock, indexPath: indexPath)
    }
    
    // MARK: - NSFetchedResultsController methods
    
    func getFetchedResultsController() -> NSFetchedResultsController<NSFetchRequestResult>
    {
        let fetchedResultsController = NSFetchedResultsController(fetchRequest: taskFetchRequest(), managedObjectContext: (LKLockRepository.sharedInstance() as AnyObject).managedObjectContext,
            sectionNameKeyPath: nil, cacheName: nil)
        return fetchedResultsController
    }
    
    func taskFetchRequest() -> NSFetchRequest<NSFetchRequestResult>
    {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "LKLock")
        let sortDescriptor = NSSortDescriptor(key: "proximity", ascending: false)
        fetchRequest.sortDescriptors = [sortDescriptor]
        return fetchRequest
    }
    
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>)
    {
        if ( !unlocking )
        {
            self.tableView.beginUpdates()
        }
        
    }

    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange object: Any, at indexPath: IndexPath?,
        for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?)
    {
        if ( !unlocking )
        {
            switch type
            {
            case .insert:
                self.tableView.insertRows(at: [newIndexPath!], with: .fade)
            case .update:
                let cell: SLLockViewCell = self.tableView.cellForRow(at: indexPath!) as! SLLockViewCell
                self.configureCell(cell, atIndexPath: indexPath!)
                self.tableView.reloadRows(at: [indexPath!], with: .fade)
            case .move:
                self.tableView.deleteRows(at: [indexPath!], with: .fade)
                self.tableView.insertRows(at: [newIndexPath!], with: .fade)
            case .delete:
                self.tableView.deleteRows(at: [indexPath!], with: .fade)
            }
        }
    }

    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>)
    {
        if ( !unlocking )
        {
            self.tableView.endUpdates()
        }
    }
    
    // MARK: - UITableViewDelegate Methods
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath)
    {
        performUnlock(indexPath)
    }
    
    func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath?
    {
        let lock: LKLock = fetchedResultsController.object(at: indexPath) as! LKLock
        if ( lock.proximity.intValue == 2 || lock.proximity.intValue == 3 )
        {
            return indexPath
        }
        return nil
    }
    
    func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        let lock: LKLock = fetchedResultsController.object(at: indexPath) as! LKLock
        if ( lock.proximity.intValue == 2 || lock.proximity.intValue == 3 )
        {
            return true
        }
        return false
    }
    
    func performUnlock(_ indexPath: IndexPath)
    {
        unlocking = true
        
        let lock: LKLock = fetchedResultsController.object(at: indexPath) as! LKLock
        let cell: SLLockViewCell = self.tableView.cellForRow(at: indexPath) as! SLLockViewCell

        cell.showInProgress()
        
        self.discoveryManager.open(lock, complete: { (success, error) -> Void in
            if ( success )
            {
                cell.showUnlocked()
            }
            else
            {
                print("ERROR opening lock: \(error?.localizedDescription)")
                
                cell.resetUnlocked()
            }
        })
        
        tableView.deselectRow(at: indexPath, animated: true)
        
        /*
        var localNotification:UILocalNotification = UILocalNotification()
        localNotification.alertAction = "Testing"
        localNotification.alertTitle = "F3"
        localNotification.alertBody = "UNLOCKING"
        localNotification.fireDate = NSDate(timeIntervalSinceNow: 20)
        localNotification.category = "lockNotification"
        UIApplication.sharedApplication().scheduleLocalNotification(localNotification)
        */
    }
    
    // MARK: - SLLockViewCellDelegate Methods
    
    func lockCompleted()
    {
        self.unlocking = false
        tableView.reloadData()
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
    
    @IBAction func doLogout(_ sender: AnyObject)
    {
        signIn?.signOut()
        checkAuthState()
    }
    
    func finished(withAuth auth: GTMOAuth2Authentication!, error: Error!)    {
        if ( error != nil )
        {
            print("google+ connect failure - finishedWithAuth: \(error.localizedDescription)")
        }
        
        checkAuthState()
    }
    
    func didDisconnectWithError(_ error: NSError!)
    {
        if ( error != nil )
        {
            print("google+ connect failure - didDisconnectWithError: \(error.localizedDescription)")
        }
        
        checkAuthState()
    }
    
    func checkAuthState()
    {
        if ( signIn?.authentication != nil )
        {
            let plusUser: GTLPlusPerson! = signIn?.googlePlusUser
            // first check to see if the domain matches
            if ( plusUser == nil || plusUser.domain != "space150.com" )
            {
                // fallback to verifying the email addres? Might want to disable this
                let email = signIn?.authentication.userEmail
                
                // check to ensure the email is on the space150.com domain!
                if ( validateEmail(email as NSString!) == false )
                {
                    signIn?.signOut()
                }
            }
        }
        
        if ( signIn?.authentication != nil )
        {
            // if we have a google plus user object
            let plusUser: GTLPlusPerson! = signIn?.googlePlusUser
            print("domain: \(plusUser.domain), url: \(plusUser.url)")
            if ( plusUser != nil )
            {
                // use the display name
                headerNameLabel.text = plusUser.displayName
                
                // and avatar image
                let backgroundQueue = DispatchQueue.global(priority: DispatchQueue.GlobalQueuePriority.default)
                backgroundQueue.async(execute: { () -> Void in
                    if ( plusUser?.image.url != nil )
                    {
                        let avatarUrl = URL(string: plusUser.image.url)!
                        let avatarData = try? Data(contentsOf: avatarUrl)
                        if ( avatarData != nil )
                        {
                            DispatchQueue.main.async(execute: { () -> Void in
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
            dismiss(animated: true, completion: { () -> Void in
                // nothing
            })
        }
        else
        {
            // clear out the header info
            headerNameLabel.text = "Unknown"
            headerImageView.image = nil
            
            // present the login view controller
            performSegue(withIdentifier: "showLogin", sender: self)
        }
    }
    
    func validateEmail(_ email: NSString!) -> Bool
    {
        let predicate = NSPredicate(format: "SELF MATCHES %@", "[A-Z0-9a-z\\._%+-]+@space150.com")
        return predicate.evaluate(with: email)
    }

}
