//
//  SLDropboxSyncViewController.swift
//  spacelab
//
//  Created by Shawn Roske on 5/18/15.
//  Copyright (c) 2015 space150. All rights reserved.
//

import UIKit
import LockKit
import KeychainAccess

class SLDropboxSyncViewController: UITableViewController,
    DBRestClientDelegate
{
    @IBOutlet weak var syncButton: UIButton!
    
    private var keychain: Keychain!
    private var outputEntries: NSMutableArray!
    private var restClient: DBRestClient!
    
    override func viewDidLoad()
    {
        super.viewDidLoad()

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem()
        
        syncButton.clipsToBounds = true
        syncButton.layer.cornerRadius = 5.0
        syncButton.layer.borderColor = UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1.0).CGColor
        syncButton.layer.borderWidth = 1.0
        
        keychain = Keychain(server: "com.s150.spacelab.spaceLock", protocolType: .HTTPS).accessibility(.WhenUnlocked)
        
        restClient = DBRestClient(session: DBSession.sharedSession())
        restClient.delegate = self
        
        outputEntries = NSMutableArray()
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        if ( DBSession.sharedSession().isLinked() )
        {
            syncButton.setTitle("Perform Sync", forState: UIControlState.Normal)
        }
        else
        {
            syncButton.setTitle("Login to Dropbox", forState: UIControlState.Normal)
        }
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
        return 1
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int
    {
        // #warning Incomplete method implementation.
        // Return the number of rows in the section.
        return outputEntries.count
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell: SLSyncDebugViewCell = tableView.dequeueReusableCellWithIdentifier("debugCell", forIndexPath: indexPath) as! SLSyncDebugViewCell

        let entry: String = outputEntries[indexPath.row] as! String
        cell.outputLabel.text = entry
        
        return cell
    }
    
    private func appendEntry(entry: String)
    {
        tableView.beginUpdates()
        
        outputEntries.addObject(entry)
        
        let newIndexPath: NSIndexPath = NSIndexPath(forItem: outputEntries.count-1, inSection: 0)
        tableView.insertRowsAtIndexPaths([newIndexPath], withRowAnimation: .Right)
        
        tableView.endUpdates()
        
        tableView.scrollToRowAtIndexPath(newIndexPath, atScrollPosition: UITableViewScrollPosition.Bottom, animated: true)
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

    @IBAction func performSyncTouched(sender: AnyObject)
    {
        if ( !DBSession.sharedSession().isLinked() )
        {
            DBSession.sharedSession().linkFromController(self)
        }
        else
        {
            // DOWNLOAD
            
            // see if we have a file in the dropbox folder
            restClient.loadMetadata("/")
            
            // unarchive it
            
            // parse the JSON
            
            // look for new entries
            
            // copy new entries in
            
            // copy images for new entries over
            
            
            performUpload()
        }
    }
    
    private func performUpload()
    {
        // UPLOAD
        let filemanager = NSFileManager.defaultManager()
        
        // fetch all the keys from the store
        let entries: NSMutableArray = NSMutableArray()
        // remove coredata entries for any locks using the key
        let fetchRequest = NSFetchRequest(entityName: "LKKey")
        let fetchResults =  LKLockRepository.sharedInstance().managedObjectContext!!.executeFetchRequest(fetchRequest, error: nil)
        if let keys = fetchResults   // check for nil and unwrap
        {
            for key in keys as! [LKKey]
            {
                // collect the keychain data
                let entry: NSMutableDictionary = NSMutableDictionary()
                entry["lockId"] = key.lockId
                entry["lockName"] = key.lockName
                let keyData = keychain.getData(key.lockId)!
                entry["keyData"] = keyData.base64EncodedStringWithOptions(NSDataBase64EncodingOptions.allZeros)
                if ( key.imageFilename != nil )
                {
                    entry["localImageFilename"] = key.imageFilename
                }
                
                entries.addObject(entry)
            }
        }
        
        let keyEntries: NSArray = entries;
        
        // export to JSON
        var jsonError: NSError?
        let jsonData = NSJSONSerialization.dataWithJSONObject(keyEntries, options: NSJSONWritingOptions.PrettyPrinted, error: &jsonError)
        if ( jsonData != nil )
        {
            let jsonString = NSString(data: jsonData!, encoding: NSUTF8StringEncoding)
            appendEntry("jsonString: \(jsonString)")
            
            // create staging folder
            let documentsDirectory: AnyObject = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)[0]
            let stagingFolder: String = documentsDirectory.stringByAppendingString("/spaceLock.backup") as String
            appendEntry("stagingFolder: \(stagingFolder)")
            if ( !filemanager.fileExistsAtPath(stagingFolder) )
            {
                var error: NSError?
                if ( !filemanager.createDirectoryAtPath(stagingFolder, withIntermediateDirectories: false, attributes: nil, error: &error) )
                {
                    appendEntry("error creating staging folder: \(error?.localizedDescription)")
                }
            }
            
            // save JSON
            let jsonPath = stagingFolder.stringByAppendingString("/contents.json")
            var contentsError: NSError?
            if ( jsonString?.writeToFile(jsonPath, atomically: true, encoding: NSUTF8StringEncoding, error: &contentsError) == false )
            {
                appendEntry("error writing contents.json: \(contentsError?.localizedDescription)")
            }
            else
            {
                // copy images to staging folder
                for key in keyEntries as! [NSDictionary]
                {
                    if ( key["localImageFilename"] != nil )
                    {
                        let lockId: String = key["lockId"] as! String
                        let imagePath = stagingFolder.stringByAppendingString("/key-\(lockId).png")
                        var copyError: NSError?
                        if ( filemanager.copyItemAtPath(key["localImageFilename"] as! String, toPath: imagePath, error: &copyError) == false )
                        {
                            appendEntry("error copying image: \(imagePath) -- \(copyError?.localizedDescription)")
                        }
                    }
                }
                
                // zip it up
                let stagingArchive: String = documentsDirectory.stringByAppendingString("/spaceLock.zip") as String
                SSZipArchive.createZipFileAtPath(stagingArchive, withContentsOfDirectory: stagingFolder)
                
                // remove staging folder
                var stagingFolderError: NSError?
                if ( filemanager.removeItemAtPath(stagingFolder, error: &stagingFolderError) == false )
                {
                    appendEntry("error removing staging folder: \(stagingFolderError?.localizedDescription)")
                }
                
                // upload it to dropbox
                restClient.uploadFile("spaceLock.zip", toPath: "/", withParentRev: nil, fromPath: stagingArchive)
            }
        }
        else
        {
            appendEntry("error: \(jsonError?.localizedDescription)")
        }
    }
    
    // MARK: - DBRestClientDelegate Methods
    
    func restClient(client: DBRestClient!, loadedMetadata metadata: DBMetadata!)
    {
        println("metadata: \(metadata)")
        if ( metadata.isDirectory )
        {
            for file: DBMetadata in metadata.contents as! [DBMetadata]
            {
                appendEntry("file: \(file.filename), date: \(file.lastModifiedDate)")
            }
        }
    }
    
    func restClient(client: DBRestClient!, uploadedFile destPath: String!, from srcPath: String!)
    {
        appendEntry("file upload SUCCEEDED: \(srcPath)")
        
        // delete the staging zip
        var error: NSError?
        if ( NSFileManager.defaultManager().removeItemAtPath(srcPath, error: &error) == false )
        {
            appendEntry("error removing srcPath: \(srcPath)")
        }
    }
    
    func restClient(client: DBRestClient!, uploadFileFailedWithError error: NSError!)
    {
        appendEntry("file upload failed: \(error?.localizedDescription)")
    }
    
}
