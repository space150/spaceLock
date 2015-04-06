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
    
    private var proximity: NSNumber!
    private var lockTimer: NSTimer!
    private var lockTimerSecondsRemaining: Int!
    
    func setLock(lock: LKLock)
    {
        doorNameLabel.setText(lock.name.uppercaseString)
        proximity = lock.proximity
        
        updateViewState()
    }
    
    private func updateViewState()
    {
        if ( proximity.integerValue == 2
            || proximity.integerValue == 3 )
        {
            statusLabel.setText("You're Good!")
            //backgroundGroup.setBackgroundColor(UIColor.greenColor())
        }
        else if ( proximity.integerValue == 1 )
        {
            statusLabel.setText("Get Closer...")
            //backgroundGroup.setBackgroundColor(UIColor.grayColor())
        }
        else
        {
            statusLabel.setText("Not In Range")
            //backgroundGroup.setBackgroundColor(UIColor.grayColor())
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
        lockImage.setImage(UIImage(named: "lock-unlocked.png"))
        
        startCountdown()
    }
    
    func startCountdown()
    {
        lockTimerSecondsRemaining = 7
        
        lockTimer = NSTimer.scheduledTimerWithTimeInterval(1.0, target: self, selector: Selector("timerTicked"), userInfo: nil, repeats: true)
    }
    
    func resetUnlocked()
    {
        lockImage.setImage(UIImage(named: "lock-normal.png"))
        
        updateViewState()
    }
    
    @objc func timerTicked()
    {
        lockTimerSecondsRemaining = lockTimerSecondsRemaining - 1
        
        statusLabel.setText(NSString(format: "Unlocked: %ds", lockTimerSecondsRemaining))
        
        if ( lockTimerSecondsRemaining <= 0 )
        {
            resetUnlocked()
        }
    }
}
