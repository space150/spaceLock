
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

    fileprivate var discoveryManager: LKLockDiscoveryManager!
    fileprivate var fetchedResultsController : NSFetchedResultsController<NSFetchRequestResult>!
    
    override func awake(withContext context: Any?)
    {
        super.awake(withContext: context)
        
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
    
    func configureTableRow(_ index: Int!)
    {
        let row = table.rowController(at: index) as! SLLockRowType
        
        let objects: NSArray = fetchedResultsController.fetchedObjects! as NSArray
        let lock: LKLock = objects.object(at: index) as! LKLock
        
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
    
    func getFetchedResultsController() -> NSFetchedResultsController<NSFetchRequestResult>
    {
        let fetchedResultsController = NSFetchedResultsController(fetchRequest: taskFetchRequest(),
            managedObjectContext: (LKLockRepository.sharedInstance() as AnyObject).managedObjectContext, sectionNameKeyPath: nil,
            cacheName: nil)
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
        // nothing
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?)
    {
        switch type
        {
        case .insert:
            table.insertRows(at: IndexSet(integer: newIndexPath!.row), withRowType: "lockRowController")
            configureTableRow(newIndexPath!.row)
        case .update:
            configureTableRow(indexPath!.row)
        case .move:
            table.removeRows(at: IndexSet(integer: indexPath!.row))
            table.insertRows(at: IndexSet(integer: newIndexPath!.row), withRowType: "lockRowController")
            configureTableRow(newIndexPath!.row)
        case .delete:
            table.removeRows(at: IndexSet(integer: indexPath!.row))
        }
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>)
    {
        // nothing
    }
    
    override func table(_ table: WKInterfaceTable, didSelectRowAt rowIndex: Int)
    {
        let objects: NSArray = fetchedResultsController.fetchedObjects! as NSArray
        let lock: LKLock = objects.object(at: rowIndex) as! LKLock
        let row = table.rowController(at: rowIndex) as! SLLockRowType
        
        if ( row.unlockable == true )
        {
            row.showInProgress()
            
            discoveryManager.open(lock, complete: { (success, error) -> Void in
                if ( success )
                {
                    row.showUnlocked()
                }
                else
                {
                    print("Error opening lock: \(error?.localizedDescription)")
                    
                    row.resetUnlocked()
                    
                    self.presentController(withName: "Error", context: ["segue": "modal", "data": error])
                }
                
            })
        }
    }

}
