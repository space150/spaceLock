//
//  SLDropboxSyncViewController.swift
//  spacelab
//
//  Created by Shawn Roske on 5/18/15.
//  Copyright (c) 2015 space150. All rights reserved.
//

import UIKit
import LockKit

class SLDropboxSyncViewController: UITableViewController,
    DBRestClientDelegate
{
    @IBOutlet var linkOverlayView: UIView!
    @IBOutlet weak var syncButton: UIBarButtonItem!
    @IBOutlet weak var linkAccountButton: UIButton!
    
    private var security: LKSecurityManager!
    private var outputEntries: NSMutableArray!
    private var restClient: DBRestClient!
    
    override func viewDidLoad()
    {
        super.viewDidLoad()

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem()
        
        security = LKSecurityManager()
        
        outputEntries = NSMutableArray()
        
        tableView.addSubview(linkOverlayView)
        
        linkOverlayView.translatesAutoresizingMaskIntoConstraints = false
        tableView.addConstraint(NSLayoutConstraint(item: linkOverlayView, attribute: .Width, relatedBy: .Equal, toItem: tableView, attribute: .Width, multiplier: 1.0, constant: 100))
        tableView.addConstraint(NSLayoutConstraint(item: linkOverlayView, attribute: .Height, relatedBy: .Equal, toItem: tableView, attribute: .Height, multiplier: 1.0, constant: 100))
        tableView.addConstraint(NSLayoutConstraint(item: linkOverlayView, attribute: .CenterX, relatedBy: .Equal, toItem: tableView, attribute: .CenterX, multiplier: 1, constant: 0))
        tableView.addConstraint(NSLayoutConstraint(item: linkOverlayView, attribute: .CenterY, relatedBy: .Equal, toItem: tableView, attribute: .CenterY, multiplier: 1, constant: 0))
        
        linkAccountButton.clipsToBounds = true
        linkAccountButton.layer.cornerRadius = 5.0
        linkAccountButton.layer.borderColor = UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1.0).CGColor
        linkAccountButton.layer.borderWidth = 1.0
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "updateDropboxLinkStatus", name: "dropbox.link.success", object: nil)
        
        updateDropboxLinkStatus()
    }
    
    func updateDropboxLinkStatus()
    {
        let linked = DBSession.sharedSession().isLinked()
        linkOverlayView.hidden = linked
        syncButton.enabled = linked
        
        restClient = DBRestClient(session: DBSession.sharedSession())
        restClient.delegate = self
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

    @IBAction func performLinkTouched(sender: AnyObject)
    {
        if ( !DBSession.sharedSession().isLinked() )
        {
            DBSession.sharedSession().linkFromController(self)
        }
    }
    
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
            print("error loading metadata, code: \(error?.code), error: \(error?.localizedDescription)")
            if error?.code == 401 {
                DBSession.sharedSession().unlinkAll()
                updateDropboxLinkStatus()
                
                appendEntry("Dropbox not correctly linked, please login!")
            }
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
        
        // parse the JSON
        let manifestPath: String = stagingFolder.stringByAppendingString("/contents.json") as String
        let jsonData = filemanager.contentsAtPath(manifestPath)
        do {
            let keyEntries: NSArray = try NSJSONSerialization.JSONObjectWithData(jsonData!, options: NSJSONReadingOptions()) as! NSArray
            // look for new entries
            for keyEntry in keyEntries as! [NSDictionary]
            {
                let lockId: String = keyEntry["lockId"] as! String
                let lockName: String = keyEntry["lockName"] as! String
                
                // see if we have an entry for this key already
                let fetchRequest = NSFetchRequest(entityName: "LKKey")
                fetchRequest.predicate = NSPredicate(format: "lockId == %@", lockId)
                let fetchResults =  try! LKLockRepository.sharedInstance().managedObjectContext!!.executeFetchRequest(fetchRequest)
                if ( fetchResults.count == 0 )
                {
                    appendEntry("Found new entry: \(lockName)")
                    
                    // if not, add it
                    let key = NSEntityDescription.insertNewObjectForEntityForName("LKKey", inManagedObjectContext: LKLockRepository.sharedInstance().managedObjectContext!!) as! LKKey
                    key.lockId = lockId
                    key.lockName = lockName
                    
                    appendEntry(" --> Copying to keychain")
                    
                    let keyData = NSData(base64EncodedString: keyEntry["keyData"] as! String, options: NSDataBase64DecodingOptions())
                    let error = security.saveKey(lockId, key: keyData!)
                    if ( error != nil )
                    {
                        appendEntry("Error saving key")
                    }
                    
                    // copy images for new entries over
                    let imagePath: String = stagingFolder.stringByAppendingString("/key-\(lockId).png") as String
                    let home = NSHomeDirectory() as NSString
                    let imageDest = home.stringByAppendingPathComponent(NSString(format: "Documents/key-%@.png", lockId) as String)
                    appendEntry(" --> Copying image for \(lockName)")
                    do {
                        try filemanager.copyItemAtPath(imagePath, toPath: imageDest)
                        key.imageFilename = imageDest
                    } catch let copyError as NSError {
                        appendEntry("Error copying image: \(imagePath) -- \(copyError.localizedDescription)")
                    } catch {
                        
                    }
                }
                else
                {
                    appendEntry("\(lockName) already exists, not merging")
                }
            }
            
            appendEntry("Committing changes...")
            LKLockRepository.sharedInstance().saveContext()
        } catch let error as NSError {
            appendEntry("Error parsing manifest: \(error.localizedDescription)")
        } catch {
            
        }
        
        // clean up the download directory
        do {
            try NSFileManager.defaultManager().removeItemAtPath(stagingFolder)
        } catch _ {
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
        let fetchResults = try! LKLockRepository.sharedInstance().managedObjectContext!!.executeFetchRequest(fetchRequest)
        let keys = fetchResults   // check for nil and unwrap
        appendEntry("Found \(keys.count) keys:")
        for key in keys as! [LKKey]
        {
            // collect the keychain data
            let entry: NSMutableDictionary = NSMutableDictionary()
            entry["lockId"] = key.lockId
            entry["lockName"] = key.lockName
            let keyData = security.findKey(key.lockId)
            if ( keyData != nil )
            {
                entry["keyData"] = keyData.base64EncodedStringWithOptions(NSDataBase64EncodingOptions())
            }
            if ( key.imageFilename != nil )
            {
                entry["localImageFilename"] = key.imageFilename
            }
            
            appendEntry(" --> Copying data for \(key.lockName)")
            
            entries.addObject(entry)
        }
        
        let keyEntries: NSArray = entries;
        
        appendEntry("Generating staging environment...")
        
        // export to JSON
        appendEntry("Generated export manifest")
        
        // create staging folder
        let documentsDirectory: AnyObject = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)[0]
        let stagingFolder: String = documentsDirectory.stringByAppendingString("/spaceLock.backup") as String
        appendEntry("Creating staging folder")
        if ( !filemanager.fileExistsAtPath(stagingFolder) )
        {
            do {
                try filemanager.createDirectoryAtPath(stagingFolder, withIntermediateDirectories: false, attributes: nil)
            } catch let error as NSError {
                appendEntry("error creating staging folder: \(error.localizedDescription)")
            } catch {}
        }
        
        // save JSON
        appendEntry("Exporting manifest to file")
        // copy images to staging folder
        appendEntry("Copying images:")
        for key in keyEntries as! [NSDictionary]
        {
            if ( key["localImageFilename"] != nil )
            {
                let lockId: String = key["lockId"] as! String
                let lockName: String = key["lockName"] as! String
                let imagePath = stagingFolder.stringByAppendingString("/key-\(lockId).png")
                appendEntry(" --> Copying image for \(lockName)")
                do {
                    try filemanager.copyItemAtPath(key["localImageFilename"] as! String, toPath: imagePath)
                } catch let error as NSError {
                    appendEntry("error copying image: \(imagePath) -- \(error.localizedDescription)")
                } catch {}
            }
        }
        
        // zip it up
        appendEntry("Archiving staging environment")
        let stagingArchive: String = documentsDirectory.stringByAppendingString("/spaceLock.zip") as String
        SSZipArchive.createZipFileAtPath(stagingArchive, withContentsOfDirectory: stagingFolder)
        
        appendEntry("Encrypting archive")
        
        // remove staging folder
        do {
            try filemanager.removeItemAtPath(stagingFolder)
        } catch let error as NSError {
            appendEntry("error removing staging folder: \(error.localizedDescription)")
        } catch {}
        
        appendEntry("Uploading spaceLock.zip to Dropbox...")
        
        // upload it to dropbox
        let dateFormatter = NSDateFormatter()
        dateFormatter.dateFormat = "yyyyMMddHHmmss"
        let str = dateFormatter.stringFromDate(NSDate())
        restClient.uploadFile("spaceLock-\(str).zip", toPath: "/", withParentRev: nil, fromPath: stagingArchive)
    }
    
    func restClient(client: DBRestClient!, uploadedFile destPath: String!, from srcPath: String!)
    {
        appendEntry("Completed file upload, DONE.")
        
        // delete the staging zip
        do {
            try NSFileManager.defaultManager().removeItemAtPath(srcPath)
        } catch _ {
            appendEntry("error removing srcPath: \(srcPath)")
        }
    }
    
    func restClient(client: DBRestClient!, uploadFileFailedWithError error: NSError!)
    {
        appendEntry("file upload failed: \(error?.localizedDescription)")
    }
    
}
