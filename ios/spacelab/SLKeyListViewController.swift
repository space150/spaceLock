//
//  SLKeyListViewController.swift
//  spacelab
//
//  Created by Shawn Roske on 5/18/15.
//  Copyright (c) 2015 space150. All rights reserved.
//

import UIKit
import LockKit
import KeychainAccess

class SLKeyListViewController: UITableViewController,
    NSFetchedResultsControllerDelegate
{
    private var keychain: Keychain!
    private var fetchedResultsController: NSFetchedResultsController!

    override func viewDidLoad() {
        super.viewDidLoad()

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem()
        
        keychain = Keychain(server: "com.s150.spacelab.spaceLock", protocolType: .HTTPS)
            .accessibility(.AfterFirstUnlock, authenticationPolicy: .UserPresence)
        
        fetchedResultsController = getFetchedResultsController()
        fetchedResultsController.delegate = self
        fetchedResultsController.performFetch(nil)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Table view data source

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int
    {
        return fetchedResultsController.sections!.count
    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int
    {
        return fetchedResultsController.sections![section].numberOfObjects
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell
    {
        let cell: SLKeyViewCell = tableView.dequeueReusableCellWithIdentifier("cell", forIndexPath: indexPath) as! SLKeyViewCell
        configureCell(cell, atIndexPath: indexPath)
        return cell
    }
    
    func configureCell(cell: SLKeyViewCell, atIndexPath indexPath: NSIndexPath)
    {
        let key: LKKey = fetchedResultsController.objectAtIndexPath(indexPath) as! LKKey
        cell.keyNameLabel.text = key.lockName;
    }

    /*
    // Override to support conditional editing of the table view.
    override func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        // Return NO if you do not want the specified item to be editable.
        return true
    }
    */

    /*
    // Override to support editing the table view.
    override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        if editingStyle == .Delete {
            // Delete the row from the data source
            tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Fade)
        } else if editingStyle == .Insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }    
    }
    */

    /*
    // Override to support rearranging the table view.
    override func tableView(tableView: UITableView, moveRowAtIndexPath fromIndexPath: NSIndexPath, toIndexPath: NSIndexPath) {

    }
    */

    /*
    // Override to support conditional rearranging of the table view.
    override func tableView(tableView: UITableView, canMoveRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        // Return NO if you do not want the item to be re-orderable.
        return true
    }
    */

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using [segue destinationViewController].
        // Pass the selected object to the new view controller.
    }
    */
    
    @IBAction func generateKeyTouched(sender: AnyObject)
    {
        performSegueWithIdentifier("generateKey", sender: self)
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
        let fetchRequest = NSFetchRequest(entityName: "LKKey")
        let sortDescriptor = NSSortDescriptor(key: "lockName", ascending: true)
        fetchRequest.sortDescriptors = [sortDescriptor]
        return fetchRequest
    }
    
    func controllerWillChangeContent(controller: NSFetchedResultsController)
    {
        self.tableView.beginUpdates()
    }
    
    func controller(controller: NSFetchedResultsController, didChangeObject object: AnyObject, atIndexPath indexPath: NSIndexPath?,
        forChangeType type: NSFetchedResultsChangeType, newIndexPath: NSIndexPath?)
    {
        switch type
        {
        case .Insert:
            self.tableView.insertRowsAtIndexPaths([newIndexPath!], withRowAnimation: .Fade)
        case .Update:
            let cell: SLKeyViewCell = self.tableView.cellForRowAtIndexPath(indexPath!) as! SLKeyViewCell
            self.configureCell(cell, atIndexPath: indexPath!)
            self.tableView.reloadRowsAtIndexPaths([indexPath!], withRowAnimation: .Fade)
        case .Move:
            self.tableView.deleteRowsAtIndexPaths([indexPath!], withRowAnimation: .Fade)
            self.tableView.insertRowsAtIndexPaths([newIndexPath!], withRowAnimation: .Fade)
        case .Delete:
            self.tableView.deleteRowsAtIndexPaths([indexPath!], withRowAnimation: .Fade)
        default:
            return
        }
    }
    
    func controllerDidChangeContent(controller: NSFetchedResultsController)
    {
        self.tableView.endUpdates()
    }
    
    override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath)
    {
        if editingStyle == UITableViewCellEditingStyle.Delete
        {
            let key: LKKey = fetchedResultsController.objectAtIndexPath(indexPath) as! LKKey
            // remove keychain entry
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
                let error = self.keychain.remove(key.lockId)
                if ( error != nil )
                {
                    let alertController = UIAlertController(title: "Unable to remove key in keychain!", message: error?.localizedDescription, preferredStyle: .Alert)
                    let okAction = UIAlertAction(title: "OK", style: .Cancel) { (action) in
                        // nothing
                    }
                    alertController.addAction(okAction)
                    self.presentViewController(alertController, animated: true) {
                        // nothing
                    }
                }
            }
            
            // remove coredata entries for any locks using the key
            let fetchRequest = NSFetchRequest(entityName: "LKLock")
            fetchRequest.predicate = NSPredicate(format: "lockId == %@", key.lockId)
            let fetchResults =  LKLockRepository.sharedInstance().managedObjectContext!!.executeFetchRequest(fetchRequest, error: nil)
            if let locks = fetchResults   // check for nil and unwrap
            {
                for lock in locks as! [LKLock]
                {
                    LKLockRepository.sharedInstance().managedObjectContext!!.deleteObject(lock)
                }
            }
            
            // LKLockRepository.sharedInstance().managedObjectContext!!.deleteObject(fetchResults[0])
            
            // remove coredata entry for the key
            LKLockRepository.sharedInstance().managedObjectContext!!.deleteObject(key)
            
            LKLockRepository.sharedInstance().saveContext()
        }
    }

}
