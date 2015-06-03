//
//  SLNewKeyViewController.swift
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

class SLNewKeyViewController: UITableViewController,
    SLKeyOutputViewCellDelegate,
    UIImagePickerControllerDelegate,
    UINavigationControllerDelegate
{
    @IBOutlet weak var lockIdLabel: UITextField!
    @IBOutlet weak var lockNameLabel: UITextField!
    @IBOutlet weak var iconImageButton: UIButton!
    @IBOutlet weak var outputLabel: UILabel!
    @IBOutlet weak var saveButton: UIBarButtonItem!
    
    private var security: LKSecurityManager!
    private var sectionCount: Int!
    private var takenImage: UIImage!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem()
        
        security = LKSecurityManager()
        
        sectionCount = 1
        
        setupIconImageCircle()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
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
    
    // MARK: - UITextField Validations
    
    @IBAction func lockIdEditingChanged(sender: AnyObject)
    {
        checkMaxLength(lockIdLabel, maxLength: 15)
    }
    
    @IBAction func lockNameEditingChanged(sender: AnyObject)
    {
        checkMaxLength(lockNameLabel, maxLength: 20)
    }
    
    func checkMaxLength(textField: UITextField!, maxLength: Int)
    {
        if (count(textField.text!) > maxLength)
        {
            textField.deleteBackward()
        }
    }
    
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
        saveButton.enabled = false
        
        let lockId = lockIdLabel.text
        let lockName = lockNameLabel.text
        
        // simple validation of input
        if ( lockId == "" || lockName == "" )
        {
            let alertController = UIAlertController(title: "Invalid", message: "Lock ID and Name are required", preferredStyle: .Alert)
            let okAction = UIAlertAction(title: "OK", style: .Cancel) { (action) in
                self.saveButton.enabled = true
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
                self.saveButton.enabled = true
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
        
        
        let error = security.saveKey(lockId, key: keyData)
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
            // update the UI on the main thread
            dispatch_async(dispatch_get_main_queue(), {
                
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
                // save the image to the filesystem
                if ( self.takenImage != nil )
                {
                    var path = NSHomeDirectory().stringByAppendingPathComponent(NSString(format: "Documents/key-%@.png", lockId) as! String)
                    let success = UIImagePNGRepresentation(self.takenImage)
                        .writeToFile(path, atomically: true)
                    if ( success == true ) {
                        println("saved image to: \(path)")
                        key.imageFilename = path
                    }
                }
                
                LKLockRepository.sharedInstance().saveContext()
                
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
    
    // MARK: - Icon Image Selection
    
    @IBAction func iconImageButtonTouched(sender: AnyObject)
    {
        var picker = UIImagePickerController()
        picker.delegate = self
        picker.allowsEditing = false
        picker.sourceType = UIImagePickerControllerSourceType.Camera
        picker.cameraCaptureMode = .Photo
        presentViewController(picker, animated: true, completion: nil)
    }
    
    //MARK: - UIImagePickerControllerDelegate Methods
    
    func imagePickerController(picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [NSObject : AnyObject])
    {
        var chosenImage = info[UIImagePickerControllerOriginalImage] as! UIImage
        takenImage = RBSquareImageTo(fixImageOrientation(chosenImage), size:CGSize(width: 300.0, height: 300.0))
        iconImageButton.setImage(takenImage, forState: UIControlState.Normal)
        
        dismissViewControllerAnimated(true, completion: nil)
    }
    
    func imagePickerControllerDidCancel(picker: UIImagePickerController)
    {
        dismissViewControllerAnimated(true, completion: nil)
    }
    
    // MARK: - Image Manipulation
    
    // image orientation fix from http://stackoverflow.com/a/27083555
    
    private func fixImageOrientation(img:UIImage) -> UIImage
    {
        // No-op if the orientation is already correct
        if (img.imageOrientation == UIImageOrientation.Up) {
            return img;
        }
        // We need to calculate the proper transformation to make the image upright.
        // We do it in 2 steps: Rotate if Left/Right/Down, and then flip if Mirrored.
        var transform:CGAffineTransform = CGAffineTransformIdentity
        
        if (img.imageOrientation == UIImageOrientation.Down
            || img.imageOrientation == UIImageOrientation.DownMirrored) {
                
                transform = CGAffineTransformTranslate(transform, img.size.width, img.size.height)
                transform = CGAffineTransformRotate(transform, CGFloat(M_PI))
        }
        
        if (img.imageOrientation == UIImageOrientation.Left
            || img.imageOrientation == UIImageOrientation.LeftMirrored) {
                
                transform = CGAffineTransformTranslate(transform, img.size.width, 0)
                transform = CGAffineTransformRotate(transform, CGFloat(M_PI_2))
        }
        
        if (img.imageOrientation == UIImageOrientation.Right
            || img.imageOrientation == UIImageOrientation.RightMirrored) {
                
                transform = CGAffineTransformTranslate(transform, 0, img.size.height);
                transform = CGAffineTransformRotate(transform,  CGFloat(-M_PI_2));
        }
        
        if (img.imageOrientation == UIImageOrientation.UpMirrored
            || img.imageOrientation == UIImageOrientation.DownMirrored) {
                
                transform = CGAffineTransformTranslate(transform, img.size.width, 0)
                transform = CGAffineTransformScale(transform, -1, 1)
        }
        
        if (img.imageOrientation == UIImageOrientation.LeftMirrored
            || img.imageOrientation == UIImageOrientation.RightMirrored) {
                
                transform = CGAffineTransformTranslate(transform, img.size.height, 0);
                transform = CGAffineTransformScale(transform, -1, 1);
        }
        
        
        // Now we draw the underlying CGImage into a new context, applying the transform
        // calculated above.
        var ctx:CGContextRef = CGBitmapContextCreate(nil, Int(img.size.width), Int(img.size.height),
            CGImageGetBitsPerComponent(img.CGImage), 0,
            CGImageGetColorSpace(img.CGImage),
            CGImageGetBitmapInfo(img.CGImage));
        CGContextConcatCTM(ctx, transform)
        
        
        if (img.imageOrientation == UIImageOrientation.Left
            || img.imageOrientation == UIImageOrientation.LeftMirrored
            || img.imageOrientation == UIImageOrientation.Right
            || img.imageOrientation == UIImageOrientation.RightMirrored
            )
        {
            CGContextDrawImage(ctx, CGRectMake(0,0,img.size.height,img.size.width), img.CGImage)
        } else {
            CGContextDrawImage(ctx, CGRectMake(0,0,img.size.width,img.size.height), img.CGImage)
        }
        
        // And now we just create a new UIImage from the drawing context
        var cgimg:CGImageRef = CGBitmapContextCreateImage(ctx)
        var imgEnd:UIImage = UIImage(CGImage: cgimg)!
        
        return imgEnd
    }
    
    // square cropped image from https://gist.github.com/hcatlin/180e81cd961573e3c54d
    
    func RBSquareImageTo(image: UIImage, size: CGSize) -> UIImage
    {
        return RBResizeImage(RBSquareImage(image), targetSize: size)
    }
    
    func RBSquareImage(image: UIImage) -> UIImage
    {
        var originalWidth  = image.size.width
        var originalHeight = image.size.height
        
        var edge: CGFloat
        if originalWidth > originalHeight {
            edge = originalHeight
        } else {
            edge = originalWidth
        }
        
        var posX = (originalWidth  - edge) / 2.0
        var posY = (originalHeight - edge) / 2.0
        
        var cropSquare = CGRectMake(posX, posY, edge, edge)
        
        var imageRef = CGImageCreateWithImageInRect(image.CGImage, cropSquare);
        return UIImage(CGImage: imageRef, scale: UIScreen.mainScreen().scale, orientation: image.imageOrientation)!
    }
    
    func RBResizeImage(image: UIImage, targetSize: CGSize) -> UIImage
    {
        let size = image.size
        
        let widthRatio  = targetSize.width  / image.size.width
        let heightRatio = targetSize.height / image.size.height
        
        // Figure out what our orientation is, and use that to form the rectangle
        var newSize: CGSize
        if(widthRatio > heightRatio) {
            newSize = CGSizeMake(size.width * heightRatio, size.height * heightRatio)
        } else {
            newSize = CGSizeMake(size.width * widthRatio,  size.height * widthRatio)
        }
        
        // This is the rect that we've calculated out and this is what is actually used below
        let rect = CGRectMake(0, 0, newSize.width, newSize.height)
        
        // Actually do the resizing to the rect using the ImageContext stuff
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.drawInRect(rect)
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage
    }
    
}
