//
//  InterfaceController.swift
//  spacelab WatchKit Extension
//
//  Created by Shawn Roske on 3/25/15.
//  Copyright (c) 2015 space150. All rights reserved.
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
        
        discoveryManager = LKLockDiscoveryManager()
        
        fetchedResultsController = getFetchedResultsController()
        fetchedResultsController.delegate = self
        fetchedResultsController.performFetch(nil)
        
        configureTableWithLocks()
    }
    
    func configureTableWithLocks()
    {
        var count: Int! = fetchedResultsController.fetchedObjects?.count
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
        var row = table.rowControllerAtIndex(index) as SLLockRowType
        
        var objects: NSArray = fetchedResultsController.fetchedObjects!
        var lock: LKLock = objects.objectAtIndex(index) as LKLock
        
        var displayString: NSString = NSString(format: "%@\n%@", "f3", lock.proximityString)
        row.rowTitleLabel.setText(displayString)
    }

    override func willActivate()
    {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()
        
        //discoveryManager.startDiscovery()
    }

    override func didDeactivate()
    {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
        
        //discoveryManager.stopDiscovery()
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
    
    func controller(controller: NSFetchedResultsController, didChangeObject object: AnyObject, atIndexPath indexPath: NSIndexPath,
        forChangeType type: NSFetchedResultsChangeType, newIndexPath: NSIndexPath)
    {
        switch type
        {
        case .Insert:
            table.insertRowsAtIndexes(NSIndexSet(index: newIndexPath.row), withRowType: "lockRowController")
            configureTableRow(newIndexPath.row)
        case .Update:
            configureTableRow(indexPath.row)
        case .Move:
            table.removeRowsAtIndexes(NSIndexSet(index: indexPath.row))
            table.insertRowsAtIndexes(NSIndexSet(index: newIndexPath.row), withRowType: "lockRowController")
            configureTableRow(newIndexPath.row)
        case .Delete:
            table.removeRowsAtIndexes(NSIndexSet(index: indexPath.row))
        default:
            return
        }
    }
    
    func controllerDidChangeContent(controller: NSFetchedResultsController)
    {
        // nothing
    }
    
    override func table(table: WKInterfaceTable, didSelectRowAtIndex rowIndex: Int)
    {
        var objects: NSArray = fetchedResultsController.fetchedObjects!
        var lock: LKLock = objects.objectAtIndex(rowIndex) as LKLock
        discoveryManager.openLock(lock, complete: { (success, error) -> Void in
            if ( success ) {
                println("lock opened!")
            }
            else {
                println("Error opening lock: \(error.localizedDescription)")
            }

        })
    }

}
