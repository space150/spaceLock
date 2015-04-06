//
//  SLLockViewCell.swift
//  spacelab
//
//  Created by Shawn Roske on 3/23/15.
//  Copyright (c) 2015 space150. All rights reserved.
//

import UIKit
import QuartzCore
import LockKit

@objc protocol SLLockViewCellDelegate
{
    optional func performUnlock(indexPath: NSIndexPath)
}

class SLLockViewCell: UITableViewCell
{
    @IBOutlet var doorNameLabel: UILabel!
    @IBOutlet var statusLabel: UILabel!
    @IBOutlet weak var actionButton: UIButton!
    @IBOutlet weak var lockIcon: UIImageView!
    @IBOutlet weak var insetBackgroundView: UIVisualEffectView!
    @IBOutlet weak var insetContainerView: UIView!
    
    var delegate: SLLockViewCellDelegate?
    
    private var proximity: NSNumber!
    private var indexPath: NSIndexPath!
    private var lockTimer: NSTimer!
    private var lockTimerSecondsRemaining: Int!
    
    func setLock(lock: LKLock, indexPath newIndexPath: NSIndexPath)
    {
        doorNameLabel.text = lock.name
        indexPath = newIndexPath
        proximity = lock.proximity
        
        updateViewState()
    }
    
    private func updateViewState()
    {
        if ( proximity.integerValue == 2
            || proximity.integerValue == 3 )
        {
            statusLabel.text = "You're Good"
            lockIcon.alpha = 1.0
            doorNameLabel.alpha = 1.0
            statusLabel.alpha = 1.0
            
            actionButton.hidden = false
            actionButton.enabled = true
        }
        else if ( proximity.integerValue == 1 )
        {
            statusLabel.text = "Get Closer"
            lockIcon.alpha = 1.0
            doorNameLabel.alpha = 1.0
            statusLabel.alpha = 1.0
            
            actionButton.hidden = false
            actionButton.enabled = false
        }
        else
        {
            // fully disabled
            statusLabel.text = "Not in Range"
            lockIcon.alpha = 0.5
            doorNameLabel.alpha = 0.5
            statusLabel.alpha = 0.5
            
            actionButton.hidden = true
            actionButton.enabled = false
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
        statusLabel.text = "Trying"
        actionButton.enabled = false
    }
    
    func showUnlocked()
    {
        lockIcon.image = UIImage(named: "lock-unlocked.png")
        actionButton.setImage(UIImage(named: "button-lock-unlocked.png"), forState: .Disabled)
        actionButton.enabled = false
        
        startCountdown()
    }
    
    func startCountdown()
    {
        lockTimerSecondsRemaining = 7
        
        lockTimer = NSTimer.scheduledTimerWithTimeInterval(1.0, target: self, selector: Selector("timerTicked"), userInfo: nil, repeats: true)
    }
    
    func resetUnlocked()
    {
        lockIcon.image = UIImage(named: "lock-normal.png")
        actionButton.setImage(UIImage(named: "button-lock-inactive.png"), forState: .Disabled)
        actionButton.enabled = true
        
        updateViewState()
    }
    
    @objc func timerTicked()
    {
        lockTimerSecondsRemaining = lockTimerSecondsRemaining - 1
        
        statusLabel.text = NSString(format: "%ds", lockTimerSecondsRemaining)

        if ( lockTimerSecondsRemaining <= 0 )
        {
            resetUnlocked()
        }
    }
    
    override func awakeFromNib()
    {
        super.awakeFromNib()
        // Initialization code
        
        println("awakeFromNib called")
        
        backgroundColor = UIColor.clearColor()
        
        insetBackgroundView.layer.cornerRadius = 10
        insetBackgroundView.layer.masksToBounds = true
        
        lockTimer = nil
        lockTimerSecondsRemaining = 0
    }

    override func setSelected(selected: Bool, animated: Bool)
    {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

    @IBAction func doUnlock(sender: AnyObject)
    {
        delegate?.performUnlock!(indexPath)
    }
}
