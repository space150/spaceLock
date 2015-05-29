//
//  AppDelegate.swift
//  spacelab
//
//  Created by Shawn Roske on 3/20/15.
//  Copyright (c) 2015 space150, Inc.
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

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate
{

    var window: UIWindow?
    
    private var keychain: Keychain!
    private var discoveryManager: LKLockDiscoveryManager!

    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool
    {
        UIApplication.sharedApplication().setStatusBarStyle(UIStatusBarStyle.LightContent, animated: true)
        
        let dbSession = DBSession(appKey: "APP_KEY_HERE", appSecret: "APP_SECRET_HERE", root: kDBRootAppFolder)
        DBSession.setSharedSession(dbSession)
        
        //! Setup keychain
        keychain = Keychain(server: "com.s150.spacelab.spaceLock", protocolType: .HTTPS).accessibility(.AfterFirstUnlock, authenticationPolicy: .UserPresence)
        //! Setup discovery manager
        discoveryManager = LKLockDiscoveryManager(context: "ios-client")
        //! Setup local notifications
        setupLocalNotifications()
        
        return true
    }
    
    func application(application: UIApplication, openURL url: NSURL, sourceApplication: String?, annotation: AnyObject?) -> Bool
    {
        if ( DBSession.sharedSession().handleOpenURL(url) )
        {
            if ( DBSession.sharedSession().isLinked() )
            {
                println("Dropbox & app linked successfully!")
                
                NSNotificationCenter.defaultCenter().postNotificationName("dropbox.link.success", object: self)
            }
            return true
        }
        return false
    }

    func applicationWillResignActive(application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        // Saves changes in the application's managed object context before the application terminates.

        LKLockRepository.sharedInstance().saveContext()
    }
    
    //! MAX TESTING LOCAL NOTIFICATIONS START
    
    func setupLocalNotifications() {
        //! Register local notifications
        registerNotifications()
        
        //! Listen for messages from extension wormhole
        var wormhole = MMWormhole(applicationGroupIdentifier: "group.com.s150.ent.spacelab", optionalDirectory: "wormhole")
        NSLog("SetupListeners")
        wormhole.listenForMessageWithIdentifier("lockProximityChange", listener: { (message) -> Void in
            //do stuff
            NSLog("PROXIMITYCHANGE")
        })
        //! Listen for notifications too, wormhole not working?
        NSNotificationCenter.defaultCenter().addObserver(
            self,
            selector: "proximityChange:",
            name: "lockProximityChange",
            object: nil
        )
    }
    
    func registerNotifications() {
        // Create notification actions
        let unlockAction = UIMutableUserNotificationAction()
        unlockAction.identifier = "UNLOCK_ACTION"
        unlockAction.title = "Unlock Door"
        unlockAction.activationMode = UIUserNotificationActivationMode.Background
        unlockAction.authenticationRequired = true
        unlockAction.destructive = false
        
        // Create notification action category
        let unlockCategory = UIMutableUserNotificationCategory()
        unlockCategory.identifier = "UNLOCK_CATEGORY"
        unlockCategory.setActions([unlockAction], forContext: UIUserNotificationActionContext.Default)
        unlockCategory.setActions([unlockAction], forContext: UIUserNotificationActionContext.Minimal)
        
        // Register for notifications
        let types = UIUserNotificationType.Alert | UIUserNotificationType.Sound
        let settings = UIUserNotificationSettings(forTypes: types, categories: NSSet(object: unlockCategory) as Set<NSObject>)
        UIApplication.sharedApplication().registerUserNotificationSettings(settings)
    }
    
    func proximityChange(notification: NSNotification) {
        let lock: LKLock = notification.object as! LKLock
        NSLog("%@ - %@", lock.name, lock.proximityString)
        var localNotification: UILocalNotification = UILocalNotification()
        localNotification.alertBody = lock.name + " - " + lock.proximityString
        localNotification.category = "UNLOCK_CATEGORY"
        localNotification.soundName = UILocalNotificationDefaultSoundName
        localNotification.userInfo = ["lockId": lock.lockId]
        UIApplication.sharedApplication().presentLocalNotificationNow(localNotification);
    }

    func application(application: UIApplication, handleActionWithIdentifier identifier: String?, forLocalNotification notification: UILocalNotification, completionHandler: () -> Void) {
        if notification.category == "UNLOCK_CATEGORY" {
            if identifier == "UNLOCK_ACTION" {
                let userInfo:Dictionary<String,String!> = notification.userInfo as! Dictionary<String,String!>
                performUnlock(userInfo["lockId"]!, completionHandler: completionHandler)
            } else {
                completionHandler()
            }
        } else {
            completionHandler()
        }
    }
    
    func performUnlock(lockId: String, completionHandler: () -> Void) {
        
        // fetch the key from the keychain
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
            let failable = self.keychain.authenticationPrompt("Retreive key for lock").getDataOrError(lockId)
            
            if failable.succeeded {
                self.discoveryManager.openLockWithId(lockId, withKey: failable.value!, complete: { (success, error) -> Void in
                    if ( success ) {
                        dispatch_async(dispatch_get_main_queue(), {
                            AudioServicesPlayAlertSound(SystemSoundID(kSystemSoundID_Vibrate))
                        })
                        completionHandler()
                    } else {
                        println("ERROR opentin lock: \(error.localizedDescription)")
                        completionHandler()
                    }
                });
                
            }
            else {
                println("error: \(failable.error?.localizedDescription)")
                completionHandler()
            }
        }
        
    }
    
    //! MAX TESTING LOCAL NOTIFICATIONS END

}

