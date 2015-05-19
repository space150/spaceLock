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
    
    // MARK: - Syncing

    @IBAction func performSyncTouched(sender: AnyObject)
    {
        if ( !DBSession.sharedSession().isLinked() )
        {
            DBSession.sharedSession().linkFromController(self)
        }
        else
        {
            syncButton.enabled = false
            
            // see if we have a file in the dropbox folder
            appendEntry("Searching for existing archive...")
            restClient.loadMetadata("/")
        }
    }
    
    func restClient(client: DBRestClient!, loadedMetadata metadata: DBMetadata!)
    {
        if ( metadata.isDirectory && metadata.contents.count > 0 )
        {
            let tmpFile = metadata.contents[0] as! DBMetadata
            var filename: String = tmpFile.filename
            var latestDate: NSDate = tmpFile.lastModifiedDate
            
            for file: DBMetadata in metadata.contents as! [DBMetadata]
            {
                if latestDate.compare(file.lastModifiedDate) == NSComparisonResult.OrderedAscending
                {
                    filename = file.filename
                    latestDate = file.lastModifiedDate
                }
            }
            
            appendEntry("Latest archive found: \(filename)")
            
            performDownload(filename);
        }
        else
        {
            appendEntry("No existing archive found")
            
            performUpload()
        }
    }
    
    func restClient(client: DBRestClient!, loadMetadataFailedWithError error: NSError!)
    {
        if ( error != nil )
        {
            performUpload()
        }
    }
    
    // MARK: - Download
    
    private func performDownload(filename: String)
    {
        // DOWNLOAD

        // download file
        appendEntry("Downloading /\(filename)...")
        let documentsDirectory: AnyObject = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)[0]
        let stagingArchivePath: String = documentsDirectory.stringByAppendingString("/spaceLock.download.zip") as String
        restClient.loadFile("/\(filename)", intoPath: stagingArchivePath)
    }
    
    func restClient(client: DBRestClient!, loadedFile destPath: String!)
    {
        let filemanager = NSFileManager.defaultManager()
        
        // unarchive it
        let documentsDirectory: AnyObject = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)[0]
        let stagingFolder: String = documentsDirectory.stringByAppendingString("/spaceLock.download") as String
        appendEntry("Extracting archive")
        if ( !SSZipArchive.unzipFileAtPath(destPath, toDestination: stagingFolder) )
        {
            appendEntry("Error extracting archive!")
        }
        
        // clean up archive
        let stagingArchivePath: String = documentsDirectory.stringByAppendingString("/spaceLock.download.zip") as String
        
        // parse the JSON
        let manifestPath: String = stagingFolder.stringByAppendingString("/contents.json") as String
        var jsonData = filemanager.contentsAtPath(manifestPath)
        var error: NSError?
        let keyEntries: NSArray = NSJSONSerialization.JSONObjectWithData(jsonData!, options: NSJSONReadingOptions.allZeros, error: &error) as! NSArray
        if ( error == nil )
        {
            // look for new entries
            for keyEntry in keyEntries as! [NSDictionary]
            {
                let lockId: String = keyEntry["lockId"] as! String
                let lockName: String = keyEntry["lockName"] as! String
                
                // see if we have an entry for this key already
                let fetchRequest = NSFetchRequest(entityName: "LKKey")
                fetchRequest.predicate = NSPredicate(format: "lockId == %@", lockId)
                let fetchResults =  LKLockRepository.sharedInstance().managedObjectContext!!.executeFetchRequest(fetchRequest, error: nil)
                if ( fetchResults?.count == 0 )
                {
                    appendEntry("Found new entry: \(lockName)")
                    
                    // if not, add it
                    let key = NSEntityDescription.insertNewObjectForEntityForName("LKKey", inManagedObjectContext: LKLockRepository.sharedInstance().managedObjectContext!!) as! LKKey
                    key.lockId = lockId
                    key.lockName = lockName
                    
                    appendEntry(" --> Copying to keychain")
                    
                    let keyData = NSData(base64EncodedString: keyEntry["keyData"] as! String, options: NSDataBase64DecodingOptions.allZeros)
                    self.keychain.set(keyData!, key: lockId)
                    
                    // copy images for new entries over
                    let imagePath: String = stagingFolder.stringByAppendingString("/key-\(lockId).png") as String
                    var imageDest = NSHomeDirectory().stringByAppendingPathComponent(NSString(format: "Documents/key-%@.png", lockId) as! String)
                    var copyError: NSError?
                    appendEntry(" --> Copying image for \(lockName)")
                    if ( filemanager.copyItemAtPath(imagePath, toPath: imageDest, error: &copyError) == false )
                    {
                        appendEntry("Error copying image: \(imagePath) -- \(copyError?.localizedDescription)")
                    }
                    else
                    {
                        key.imageFilename = imageDest
                    }
                }
                else
                {
                    appendEntry("\(lockName) already exists, not merging")
                }
            }
            
            appendEntry("Committing changes...")
            LKLockRepository.sharedInstance().saveContext()
        }
        else
        {
            appendEntry("Error parsing manifest: \(error?.localizedDescription)")
        }
        
        // clean up the download directory
        var cleanupError: NSError?
        if ( NSFileManager.defaultManager().removeItemAtPath(stagingFolder, error: &cleanupError) == false )
        {
            appendEntry("error removing srcPath: \(stagingFolder)")
        }
        
        performUpload()
    }
    
    // MARK: - Upload
    
    private func performUpload()
    {
        // UPLOAD
        let filemanager = NSFileManager.defaultManager()
        
        appendEntry("Copying keys from the Keychain...")
        
        // fetch all the keys from the store
        let entries: NSMutableArray = NSMutableArray()
        // remove coredata entries for any locks using the key
        let fetchRequest = NSFetchRequest(entityName: "LKKey")
        let fetchResults =  LKLockRepository.sharedInstance().managedObjectContext!!.executeFetchRequest(fetchRequest, error: nil)
        if let keys = fetchResults   // check for nil and unwrap
        {
            appendEntry("Found \(keys.count) keys:")
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
                
                appendEntry(" --> Copying data for \(key.lockName)")
                
                entries.addObject(entry)
            }
        }
        
        let keyEntries: NSArray = entries;
        
        appendEntry("Generating staging environment...")
        
        // export to JSON
        var jsonError: NSError?
        let jsonData = NSJSONSerialization.dataWithJSONObject(keyEntries, options: NSJSONWritingOptions.PrettyPrinted, error: &jsonError)
        if ( jsonData != nil )
        {
            let jsonString = NSString(data: jsonData!, encoding: NSUTF8StringEncoding)
            appendEntry("Generated export manifest")
            
            // create staging folder
            let documentsDirectory: AnyObject = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)[0]
            let stagingFolder: String = documentsDirectory.stringByAppendingString("/spaceLock.backup") as String
            appendEntry("Creating staging folder")
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
            appendEntry("Exporting manifest to file")
            if ( jsonString?.writeToFile(jsonPath, atomically: true, encoding: NSUTF8StringEncoding, error: &contentsError) == false )
            {
                appendEntry("error writing contents.json: \(contentsError?.localizedDescription)")
            }
            else
            {
                // copy images to staging folder
                appendEntry("Copying images:")
                for key in keyEntries as! [NSDictionary]
                {
                    if ( key["localImageFilename"] != nil )
                    {
                        let lockId: String = key["lockId"] as! String
                        let lockName: String = key["lockName"] as! String
                        let imagePath = stagingFolder.stringByAppendingString("/key-\(lockId).png")
                        var copyError: NSError?
                        appendEntry(" --> Copying image for \(lockName)")
                        if ( filemanager.copyItemAtPath(key["localImageFilename"] as! String, toPath: imagePath, error: &copyError) == false )
                        {
                            appendEntry("error copying image: \(imagePath) -- \(copyError?.localizedDescription)")
                        }
                    }
                }
                
                // zip it up
                appendEntry("Archiving staging environment")
                let stagingArchive: String = documentsDirectory.stringByAppendingString("/spaceLock.zip") as String
                SSZipArchive.createZipFileAtPath(stagingArchive, withContentsOfDirectory: stagingFolder)
                
                appendEntry("Encrypting archive")
                
                // remove staging folder
                var stagingFolderError: NSError?
                if ( filemanager.removeItemAtPath(stagingFolder, error: &stagingFolderError) == false )
                {
                    appendEntry("error removing staging folder: \(stagingFolderError?.localizedDescription)")
                }
                
                appendEntry("Uploading spaceLock.zip to Dropbox...")
                
                // upload it to dropbox
                restClient.uploadFile("spaceLock.zip", toPath: "/", withParentRev: nil, fromPath: stagingArchive)
            }
        }
        else
        {
            appendEntry("error: \(jsonError?.localizedDescription)")
        }
    }
    
    func restClient(client: DBRestClient!, uploadedFile destPath: String!, from srcPath: String!)
    {
        appendEntry("Completed file upload, DONE.")
        
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
