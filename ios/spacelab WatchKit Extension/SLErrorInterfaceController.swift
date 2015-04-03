//
//  SLErrorInterfaceController.swift
//  spacelab
//
//  Created by Shawn Roske on 4/3/15.
//  Copyright (c) 2015 space150. All rights reserved.
//

import WatchKit
import Foundation


class SLErrorInterfaceController: WKInterfaceController
{
    @IBOutlet weak var errorLabel: WKInterfaceLabel!

    @IBAction func okPressed()
    {
        dismissController()
    }
    
    override func awakeWithContext(context: AnyObject?) {
        super.awakeWithContext(context)
        
        // Configure interface objects here.
        
        if ( context != nil )
        {
            var c : NSDictionary = context as NSDictionary
            var error : NSError = c["data"] as NSError!
            errorLabel.setText(error.localizedDescription)
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
