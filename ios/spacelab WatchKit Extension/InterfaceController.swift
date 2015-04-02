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

class InterfaceController: WKInterfaceController
{
    @IBOutlet weak var table: WKInterfaceTable!
    
    override func awakeWithContext(context: AnyObject?)
    {
        super.awakeWithContext(context)
        
        fetchLocks()
        
        configureTableWithData(["F3", "spacelab", "Roske", "Roske", "Roske"]);
    }
    
    func fetchLocks()
    {
        var request = NSFetchRequest()
        var entity = NSEntityDescription.entityForName("LKLock", inManagedObjectContext: LKLockRepository.sharedInstance().managedObjectContext!)
        request.entity = entity
        
        let sortDescriptor = NSSortDescriptor(key: "lastActionAt", ascending: false)
        let sortDescriptors = [sortDescriptor]
        
        request.sortDescriptors = sortDescriptors
        
        var error: NSError? = nil
        let results = LKLockRepository.sharedInstance().managedObjectContext?.executeFetchRequest(request, error: &error)
        
        LKLockRepository.sharedInstance().saveContext()

        var count : Int! = results?.count
        for index in 0...count-1 {
            var lock : LKLock = results?[index] as LKLock!
            println("lock, name: \(lock.name), uuid: \(lock.uuid)")
        }
    }
    
    func configureTableWithData(array: NSArray)
    {
        table.setNumberOfRows(array.count, withRowType: "lockRowController")
        println("table.numberOfRows: \(table.numberOfRows)")
        for i in 0...(table.numberOfRows-1)
        {
            var row = table.rowControllerAtIndex(i) as SLLockRowType
            var title = array.objectAtIndex(i) as NSString
            row.rowTitleLabel.setText(title)
        }
    }

    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()
    }

    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
    }

}
