//
//  InterfaceController.swift
//  spacelab WatchKit Extension
//
//  Created by Shawn Roske on 3/25/15.
//  Copyright (c) 2015 space150. All rights reserved.
//

import WatchKit
import Foundation


class InterfaceController: WKInterfaceController
{
    @IBOutlet weak var table: WKInterfaceTable!
    
    override func awakeWithContext(context: AnyObject?)
    {
        super.awakeWithContext(context)
        
        configureTableWithData(["F3", "spacelab", "Roske", "Roske", "Roske"]);
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
