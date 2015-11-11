
//
//  InterfaceController.swift
//  spacelab WatchKit Extension
//
//  Created by Shawn Roske on 3/25/15.
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

import WatchKit
import Foundation
import LockKit

class InterfaceController: WKInterfaceController, NSFetchedResultsControllerDelegate
{
    @IBOutlet weak var table: WKInterfaceTable!

    private var discoveryManager: LKLockDiscoveryManager!
    private var fetchedResultsController : NSFetchedResultsController!
    
    override func awakeWithContext(context: AnyObject?)
    {
        super.awakeWithContext(context)
        
        discoveryManager = LKLockDiscoveryManager(context: "watchkit-ext")
        
        fetchedResultsController = getFetchedResultsController()
        fetchedResultsController.delegate = self
        try! fetchedResultsController.performFetch()
        
        configureTableWithLocks()
    }
    
    func configureTableWithLocks()
    {
        let count: Int! = fetchedResultsController.fetchedObjects?.count
        table.setNumberOfRows(count, withRowType: "lockRowController")
        if ( count > 0 )
        {
            for i in 0...(count-1)
            {
                configureTableRow(i)
            }
        }
    }
    
    func configureTableRow(index: Int!)
    {
        let row = table.rowControllerAtIndex(index) as! SLLockRowType
        
        let objects: NSArray = fetchedResultsController.fetchedObjects!
        let lock: LKLock = objects.objectAtIndex(index) as! LKLock
        
        row.setLock(lock)
    }

    override func willActivate()
    {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()
        
        discoveryManager.startDiscovery()
    }

    override func didDeactivate()
    {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
        
        discoveryManager.stopDiscovery()
    }
    
    // MARK: - NSFetchedResultsController methods
    
    func getFetchedResultsController() -> NSFetchedResultsController
    {
        let fetchedResultsController = NSFetchedResultsController(fetchRequest: taskFetchRequest(),
            managedObjectContext: LKLockRepository.sharedInstance().managedObjectContext, sectionNameKeyPath: nil,
            cacheName: nil)
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
        // nothing
    }
    
    func controller(controller: NSFetchedResultsController, didChangeObject anObject: AnyObject, atIndexPath indexPath: NSIndexPath?, forChangeType type: NSFetchedResultsChangeType, newIndexPath: NSIndexPath?)
    {
        switch type
        {
        case .Insert:
            table.insertRowsAtIndexes(NSIndexSet(index: newIndexPath!.row), withRowType: "lockRowController")
            configureTableRow(newIndexPath!.row)
        case .Update:
            configureTableRow(indexPath!.row)
        case .Move:
            table.removeRowsAtIndexes(NSIndexSet(index: indexPath!.row))
            table.insertRowsAtIndexes(NSIndexSet(index: newIndexPath!.row), withRowType: "lockRowController")
            configureTableRow(newIndexPath!.row)
        case .Delete:
            table.removeRowsAtIndexes(NSIndexSet(index: indexPath!.row))
        }
    }
    
    func controllerDidChangeContent(controller: NSFetchedResultsController)
    {
        // nothing
    }
    
    override func table(table: WKInterfaceTable, didSelectRowAtIndex rowIndex: Int)
    {
        let objects: NSArray = fetchedResultsController.fetchedObjects!
        let lock: LKLock = objects.objectAtIndex(rowIndex) as! LKLock
        let row = table.rowControllerAtIndex(rowIndex) as! SLLockRowType
        
        if ( row.unlockable == true )
        {
            row.showInProgress()
            
            discoveryManager.openLock(lock, complete: { (success, error) -> Void in
                if ( success )
                {
                    row.showUnlocked()
                }
                else
                {
                    print("Error opening lock: \(error.localizedDescription)")
                    
                    row.resetUnlocked()
                    
                    self.presentControllerWithName("Error", context: ["segue": "modal", "data": error])
                }
                
            })
        }
    }

}
