//
//  SLKeyListViewController.swift
//  spacelab
//
//  Created by Shawn Roske on 5/18/15.
//  Copyright (c) 2015 space150. All rights reserved.
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

class SLKeyListViewController: UITableViewController,
    NSFetchedResultsControllerDelegate
{
    private var security: LKSecurityManager!
    private var fetchedResultsController: NSFetchedResultsController!

    override func viewDidLoad() {
        super.viewDidLoad()

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem()
        
        security = LKSecurityManager()

        fetchedResultsController = getFetchedResultsController()
        fetchedResultsController.delegate = self
        fetchedResultsController.performFetch(nil)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewDidAppear(animated: Bool)
    {
        super.viewDidAppear(animated)
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

    // MARK: - Navigation

    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?)
    {
        if ( segue.identifier == "showKey" )
        {
            let key: LKKey = fetchedResultsController.objectAtIndexPath(self.tableView.indexPathForSelectedRow()!) as! LKKey
            var controller: SLShowKeyViewController = segue.destinationViewController as! SLShowKeyViewController
            controller.key = key
        }
    }
    
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
            let error = security.deleteKey(key.lockId)
            if ( error != nil )
            {
                println("unable to delete key: \(error.localizedDescription)")
            }
            
            // delete image
            var path = NSHomeDirectory().stringByAppendingPathComponent(NSString(format: "Documents/key-%@.png", key.lockId) as! String)
            let fileManager = NSFileManager.defaultManager()
            fileManager.removeItemAtPath(path, error: nil)
            
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
            
            // remove coredata entry for the key
            LKLockRepository.sharedInstance().managedObjectContext!!.deleteObject(key)
            
            LKLockRepository.sharedInstance().saveContext()
        }
    }

}
