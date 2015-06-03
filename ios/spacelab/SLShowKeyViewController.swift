//
//  SLShowKeyViewController.swift
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

class SLShowKeyViewController: UITableViewController,
    SLKeyOutputViewCellDelegate
{
    @IBOutlet weak var lockIdLabel: UILabel!
    @IBOutlet weak var lockNameLabel: UILabel!
    @IBOutlet weak var iconImageButton: UIButton!
    @IBOutlet weak var outputLabel: UILabel!
    
    var key: LKKey!
    private var security: LKSecurityManager!

    override func viewDidLoad()
    {
        super.viewDidLoad()

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem()
        
        security = LKSecurityManager()
        
        setupIconImageCircle()
    }
    
    override func viewWillAppear(animated: Bool)
    {
        super.viewWillAppear(animated)
        
        updateViewForKey()
    }
    
    private func updateViewForKey()
    {
        lockIdLabel.text = key.lockId;
        lockNameLabel.text = key.lockName;
        if ( key.imageFilename != nil )
        {
            iconImageButton.setImage(UIImage(contentsOfFile: key.imageFilename), forState: UIControlState.Normal)
        }

        var keyData = security.findKey(key.lockId)
        if keyData != nil
        {
            let handshakeData: NSData = self.security.encryptString(self.key.lockId, withKey: keyData)
            
            // update the UI on the main thread
            dispatch_async(dispatch_get_main_queue(), {
                self.outputLabel.text = NSString(format: "#define LOCK_NAME \"%@\"\nbyte key[] = {\n%@\n};\nchar handshake[] = {\n%@\n};", self.key.lockId,
                    keyData.hexadecimalString(),
                    handshakeData.hexadecimalString()) as String
            })
        }
        else
        {
            println("error: unable to find key")
            // Error handling if needed...
        }
    }
    
    private func setupIconImageCircle()
    {
        var path = UIBezierPath(ovalInRect: iconImageButton.bounds)
        
        var maskLayer = CAShapeLayer()
        maskLayer.path = path.CGPath
        iconImageButton.layer.mask = maskLayer
        
        var outlineLayer = CAShapeLayer()
        outlineLayer.lineWidth = 10.0
        outlineLayer.fillColor = UIColor.clearColor().CGColor
        outlineLayer.strokeColor = UIColor(red: 0.7, green: 0.7, blue: 0.7, alpha: 1.0).CGColor
        outlineLayer.path = path.CGPath
        iconImageButton.layer.addSublayer(outlineLayer)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Table view data source

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int
    {
        // #warning Potentially incomplete method implementation.
        // Return the number of sections.
        return 2
    }

    /*
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete method implementation.
        // Return the number of rows in the section.
        return 0
    }
    */

    /*
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("reuseIdentifier", forIndexPath: indexPath) as! UITableViewCell

        // Configure the cell...

        return cell
    }
    */

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
    
    // MARK: - SLKeyOutputViewCellDelegate Methods
    
    func doCopy(sender: AnyObject?)
    {
        let cell: SLKeyOutputViewCell = sender as! SLKeyOutputViewCell
        cell.delegate = nil
        
        UIPasteboard.generalPasteboard().string = outputLabel.text
        println("added: \(outputLabel.text) to the pasteboard")
    }
    
    // MARK: - UITableViewDelegate Methods
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath)
    {
        if ( indexPath.section == 1 && indexPath.row == 0 )
        {
            let cell: SLKeyOutputViewCell = tableView.cellForRowAtIndexPath(indexPath) as! SLKeyOutputViewCell
            cell.delegate = self
            cell.becomeFirstResponder()
            
            let controller = UIMenuController.sharedMenuController()
            controller.setTargetRect(cell.frame, inView: view)
            controller.setMenuVisible(true, animated: true)
            
            tableView.deselectRowAtIndexPath(indexPath, animated: true)
        }
    }

}
