//
//  SLNewKeyViewController.swift
//  spacelab
//
//  Created by Shawn Roske on 5/18/15.
//  Copyright (c) 2015 space150. All rights reserved.
//

import UIKit
import LockKit
import KeychainAccess

class SLNewKeyViewController: UITableViewController, SLKeyOutputViewCellDelegate
{
    @IBOutlet weak var lockIdLabel: UITextField!
    @IBOutlet weak var lockNameLabel: UITextField!
    @IBOutlet weak var generateKeyButton: UIButton!
    @IBOutlet weak var outputLabel: UILabel!
    
    private var keychain: Keychain!
    private var security: LKSecurityManager!
    private var sectionCount: Int!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem()
        
        keychain = Keychain(server: "com.s150.spacelab.spaceLock", protocolType: .HTTPS)
            .accessibility(.AfterFirstUnlock, authenticationPolicy: .UserPresence)
        security = LKSecurityManager()
        
        sectionCount = 1
        
        generateKeyButton.clipsToBounds = true
        generateKeyButton.layer.cornerRadius = 5.0
        generateKeyButton.layer.borderColor = UIColor(red: 0.8, green: 0.8, blue: 0.8, alpha: 1.0).CGColor
        generateKeyButton.layer.borderWidth = 1.0
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Table view data source

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        // #warning Potentially incomplete method implementation.
        // Return the number of sections.
        return sectionCount
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
    
    // MARK: - Key Generation

    @IBAction func generateKeyTouched(sender: AnyObject)
    {
        let lockId = lockIdLabel.text
        let lockName = lockNameLabel.text
        
        // simple validation of input
        if ( lockId == "" || lockName == "" )
        {
            let alertController = UIAlertController(title: "Invalid", message: "Lock ID and Name are required", preferredStyle: .Alert)
            let okAction = UIAlertAction(title: "OK", style: .Cancel) { (action) in
                // nothing
            }
            alertController.addAction(okAction)
            self.presentViewController(alertController, animated: true) {
                // nothing
            }
            return;
        }
        
        // check to see if this key already exists
        if ( validateKey(lockId, name: lockName) )
        {
            saveKey()
        }
        else
        {
            let alertController = UIAlertController(title: "A key with that ID already exists!", message: "Are you positive you would like to generate a new key? DOING SO WILL DESTROY THE EXISTING KEY!", preferredStyle: .Alert)
            let cancelAction = UIAlertAction(title: "Cancel", style: .Cancel) { (action) in
                // nothing
            }
            alertController.addAction(cancelAction)
            let OKAction = UIAlertAction(title: "Yes", style: .Default) { (action) in
                self.saveKey()
            }
            alertController.addAction(OKAction)
            self.presentViewController(alertController, animated: true) {
                // nothing
            }
        }
    }
    
    private func validateKey(id: String, name: String) -> Bool
    {
        let fetchRequest = NSFetchRequest(entityName: "LKKey")
        fetchRequest.predicate = NSPredicate(format: "lockId == %@", id)
        let fetchResults =  LKLockRepository.sharedInstance().managedObjectContext!!.executeFetchRequest(fetchRequest, error: nil)
        if ( fetchResults?.count == 0 ) {
            return true
        }
        return false
    }
    
    private func saveKey()
    {
        let lockId = lockIdLabel.text
        let lockName = lockNameLabel.text
        
        // generate key and store it in the keychain
        let keyData: NSData = security.generateNewKeyForLockName(lockId)!
        let handshakeData: NSData = security.encryptString(lockId, withKey: keyData)
        
        // save key to the keychain (in a background thread)
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
            let error = self.keychain.set(keyData, key: lockId)
            if ( error != nil )
            {
                let alertController = UIAlertController(title: "Unable to save key in keychain!", message: error?.localizedDescription, preferredStyle: .Alert)
                let okAction = UIAlertAction(title: "OK", style: .Cancel) { (action) in
                    // nothing
                }
                alertController.addAction(okAction)
                self.presentViewController(alertController, animated: true) {
                    // nothing
                }
            }
            else
            {
                // find or update coredata entry
                var key: LKKey;
                let fetchRequest = NSFetchRequest(entityName: "LKKey")
                fetchRequest.predicate = NSPredicate(format: "lockId == %@", lockId)
                let fetchResults =  LKLockRepository.sharedInstance().managedObjectContext!!.executeFetchRequest(fetchRequest, error: nil)
                if ( fetchResults?.count > 0 )
                {
                    key = fetchResults?.first as! LKKey
                    key.lockName = lockName
                }
                else
                {
                    key = NSEntityDescription.insertNewObjectForEntityForName("LKKey", inManagedObjectContext: LKLockRepository.sharedInstance().managedObjectContext!!) as! LKKey
                    key.lockId = lockId
                    key.lockName = lockName
                }
                LKLockRepository.sharedInstance().saveContext()
                
                // update the UI on the main thread
                dispatch_async(dispatch_get_main_queue(), {
                    
                    // display sketch info
                    self.outputLabel.text = NSString(format: "#define LOCK_NAME \"%@\"\nbyte key[] = {\n%@\n};\nchar handshake[] = {\n%@\n};", lockId,
                        keyData.hexadecimalString(),
                        handshakeData.hexadecimalString()) as String
                    
                    // update the table view so it displays the sketch info
                    self.sectionCount = 2
                    self.tableView.reloadData()
                })
            }
        }
    }
}
