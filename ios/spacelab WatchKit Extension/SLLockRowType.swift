//
//  SLLockRowType.swift
//  spacelab
//
//  Created by Shawn Roske on 3/25/15.
//  Copyright (c) 2015 space150. All rights reserved.
//

import WatchKit
import LockKit

class SLLockRowType: NSObject
{
    @IBOutlet weak var backgroundGroup: WKInterfaceGroup!
    @IBOutlet weak var doorNameLabel: WKInterfaceLabel!
    @IBOutlet weak var statusLabel: WKInterfaceLabel!
    @IBOutlet weak var lockImage: WKInterfaceImage!
    
    var unlockable: Bool!
    private var proximity: NSNumber!
    private var lockTimer: NSTimer!
    private var lockTimerSecondsRemaining: Int!
    
    func setLock(lock: LKLock)
    {
        var components: NSArray = lock.name.uppercaseString.componentsSeparatedByString("-")
        doorNameLabel.setText(components.lastObject as NSString)
        proximity = lock.proximity
        
        updateViewState()
    }
    
    private func updateViewState()
    {
        if ( proximity.integerValue == 2
            || proximity.integerValue == 3 )
        {
            statusLabel.setText("You're Good!")
            backgroundGroup.setBackgroundColor(UIColor(red: 47.0/255.0, green: 153.0/255.0, blue: 50.0/255.0, alpha: 1.0))
            doorNameLabel.setTextColor(UIColor.whiteColor())
            statusLabel.setTextColor(UIColor.whiteColor())
            lockImage.setImageNamed("lock-normal")
            
            unlockable = true
        }
        else if ( proximity.integerValue == 1 )
        {
            statusLabel.setText("Get Closer...")
            backgroundGroup.setBackgroundColor(UIColor(red: 49.0/255.0, green: 49.0/255.0, blue: 51.0/255.0, alpha: 1.0))
            doorNameLabel.setTextColor(UIColor.whiteColor())
            statusLabel.setTextColor(UIColor.whiteColor())
            lockImage.setImageNamed("lock-normal")
            
            unlockable = false
        }
        else
        {
            statusLabel.setText("Not In Range")
            backgroundGroup.setBackgroundColor(UIColor(red: 34.0/255.0, green: 35.0/255.0, blue: 36.0/255.0, alpha: 1.0))
            doorNameLabel.setTextColor(UIColor(red: 77.0/255.0, green: 77.0/255.0, blue: 77.0/255.0, alpha: 1.0))
            statusLabel.setTextColor(UIColor(red: 77.0/255.0, green: 77.0/255.0, blue: 77.0/255.0, alpha: 1.0))
            lockImage.setImageNamed("lock-inactive")
            
            unlockable = false
        }
        
        if ( lockTimer != nil )
        {
            lockTimerSecondsRemaining = 0
            
            lockTimer.invalidate()
            lockTimer = nil
        }
    }
    
    func showInProgress()
    {
        statusLabel.setText("Trying")
    }
    
    func showUnlocked()
    {
        lockImage.setImageNamed("lock-unlocked")
        
        startCountdown()
    }
    
    func startCountdown()
    {
        lockTimerSecondsRemaining = 7
        
        lockTimer = NSTimer.scheduledTimerWithTimeInterval(1.0, target: self, selector: Selector("timerTicked"), userInfo: nil, repeats: true)
    }
    
    func resetUnlocked()
    {
        lockImage.setImageNamed("lock-normal")
        
        updateViewState()
    }
    
    @objc func timerTicked()
    {
        lockTimerSecondsRemaining = lockTimerSecondsRemaining - 1
        
        statusLabel?.setText(NSString(format: "Unlocked: %ds", lockTimerSecondsRemaining))
        
        if ( lockTimerSecondsRemaining <= 0 )
        {
            resetUnlocked()
        }
    }
}
