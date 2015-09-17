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
import AudioToolbox

class SLLockViewController: UIViewController,
    UITableViewDelegate,
    UITableViewDataSource,
    NSFetchedResultsControllerDelegate,
    SLLockViewCellDelegate
{
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var logoutButton: UIButton!
    @IBOutlet weak var noResultsView: UIView!
    
    private var fetchedResultsController: NSFetchedResultsController!
    
    private var discoveryManager: LKLockDiscoveryManager!
    private var unlocking:Bool!
    
    private var security: LKSecurityManager!
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        discoveryManager = LKLockDiscoveryManager(context: "ios-client")
        
        unlocking = false
        
        security = LKSecurityManager()
        
        fetchedResultsController = getFetchedResultsController()
        fetchedResultsController.delegate = self
        try! fetchedResultsController.performFetch()
    }
    
    override func viewDidAppear(animated: Bool)
    {
        super.viewDidAppear(animated)
        
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
    
    func numberOfSectionsInTableView(tableView: UITableView) -> Int
    {
        return fetchedResultsController.sections!.count
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int
    {
        return fetchedResultsController.sections![section].numberOfObjects
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell
    {
        var cell:SLLockViewCell = self.tableView.dequeueReusableCellWithIdentifier("cell") as! SLLockViewCell
        configureCell(cell, atIndexPath: indexPath)
        return cell
    }
    
    func configureCell(cell: SLLockViewCell, atIndexPath indexPath: NSIndexPath)
    {
        let lock: LKLock = fetchedResultsController.objectAtIndexPath(indexPath) as! LKLock
        cell.delegate = self
        cell.setLock(lock, indexPath: indexPath)
    }
    
    // MARK: - NSFetchedResultsController methods
    
    func getFetchedResultsController() -> NSFetchedResultsController
    {
        let fetchedResultsController = NSFetchedResultsController(fetchRequest: taskFetchRequest(), managedObjectContext: LKLockRepository.sharedInstance().managedObjectContext!!,
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
        if ( !unlocking )
        {
            self.tableView.beginUpdates()
        }
    }

    func controller(controller: NSFetchedResultsController, didChangeObject object: AnyObject, atIndexPath indexPath: NSIndexPath?,
        forChangeType type: NSFetchedResultsChangeType, newIndexPath: NSIndexPath?)
    {
        if ( !unlocking )
        {
            switch type
            {
            case .Insert:
                self.tableView.insertRowsAtIndexPaths([newIndexPath!], withRowAnimation: .Fade)
            case .Update:
                if ( self.tableView.cellForRowAtIndexPath(indexPath!) != nil )
                {
                    let cell: SLLockViewCell = self.tableView.cellForRowAtIndexPath(indexPath!) as! SLLockViewCell
                    self.configureCell(cell, atIndexPath: indexPath!)
                    self.tableView.reloadRowsAtIndexPaths([indexPath!], withRowAnimation: .Fade)
                }
            case .Move:
                self.tableView.deleteRowsAtIndexPaths([indexPath!], withRowAnimation: .Fade)
                self.tableView.insertRowsAtIndexPaths([newIndexPath!], withRowAnimation: .Fade)
            case .Delete:
                self.tableView.deleteRowsAtIndexPaths([indexPath!], withRowAnimation: .Fade)
            default:
                return
            }
        }
    }

    func controllerDidChangeContent(controller: NSFetchedResultsController)
    {
        if ( !unlocking )
        {
            self.tableView.endUpdates()
            noResultsView.hidden = ( fetchedResultsController.fetchedObjects?.count > 0 )
        }
    }
    
    // MARK: - UITableViewDelegate Methods
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath)
    {
        performUnlock(indexPath)
    }
    
    func tableView(tableView: UITableView, willSelectRowAtIndexPath indexPath: NSIndexPath) -> NSIndexPath?
    {
        let lock: LKLock = fetchedResultsController.objectAtIndexPath(indexPath) as! LKLock
        if ( lock.proximity.integerValue == 2 || lock.proximity.integerValue == 3 )
        {
            return indexPath
        }
        return nil
    }
    
    func tableView(tableView: UITableView, shouldHighlightRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        let lock: LKLock = fetchedResultsController.objectAtIndexPath(indexPath) as! LKLock
        if ( lock.proximity.integerValue == 2 || lock.proximity.integerValue == 3 )
        {
            return true
        }
        return false
    }
    
    func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath)
    {
        if editingStyle == UITableViewCellEditingStyle.Delete
        {
            // remove coredata entry
            let lock: LKLock = fetchedResultsController.objectAtIndexPath(indexPath) as! LKLock
            LKLockRepository.sharedInstance().managedObjectContext!!.deleteObject(lock)
            LKLockRepository.sharedInstance().saveContext()
        }
    }
    
    func performUnlock(indexPath: NSIndexPath)
    {
        unlocking = true
        
        let lock: LKLock = fetchedResultsController.objectAtIndexPath(indexPath) as! LKLock
        let cell: SLLockViewCell = self.tableView.cellForRowAtIndexPath(indexPath) as! SLLockViewCell

        cell.showInProgress()
        
        // fetch the key from the keychain
        var keyData = security.findKey(lock.lockId)
        if keyData != nil
        {
            self.discoveryManager.openLock(lock, withKey:keyData, complete: { (success, error) -> Void in
                if ( success )
                {
                    dispatch_async(dispatch_get_main_queue(), {
                        AudioServicesPlayAlertSound(SystemSoundID(kSystemSoundID_Vibrate))
                        cell.showUnlocked()
                    })
                }
                else
                {
                    print("ERROR opening lock: \(error.localizedDescription)")
                    
                    dispatch_async(dispatch_get_main_queue(), {
                        cell.resetUnlocked()
                    })
                }
            })
            
        }
        else
        {
            print("error: unable to find key")
            
            dispatch_async(dispatch_get_main_queue(), {
                cell.resetUnlocked()
            })
        }
        
        tableView.deselectRowAtIndexPath(indexPath, animated: true)
    }
    
    // MARK: - SLLockViewCellDelegate Methods
    
    func lockCompleted()
    {
        self.unlocking = false
        tableView.reloadData()
    }
    
}