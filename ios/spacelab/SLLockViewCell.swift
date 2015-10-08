//
//  SLLockViewCell.swift
//  spacelab
//
//  Created by Shawn Roske on 3/23/15.
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
import QuartzCore
import LockKit
import Darwin

@objc protocol SLLockViewCellDelegate
{
    optional func lockCompleted()
}

class SLLockViewCell: UITableViewCell
{
    @IBOutlet weak var lockIconImageView: UIImageView!
    @IBOutlet weak var lockNameLabel: UILabel!
    @IBOutlet weak var lockStatusLabel: UILabel!
    
    var delegate: SLLockViewCellDelegate?
    
    private var proximity: NSNumber!
    private var indexPath: NSIndexPath!
    private var lockTimer: NSTimer!
    private var lockTimerSecondsRemaining: Int!
    
    private var maskLayer: CAShapeLayer!
    private var outlineLayer: CAShapeLayer!
    private var path: UIBezierPath!
    
    func setLock(lock: LKLock, indexPath newIndexPath: NSIndexPath)
    {
        indexPath = newIndexPath
        proximity = lock.proximity
        
        lockNameLabel.text = lock.name
        if ( lock.icon != nil )
        {
            lockIconImageView.image = UIImage(contentsOfFile: lock.icon)
        }
        
        updateViewState()
    }
    
    private func updateViewState()
    {
        if ( proximity.integerValue == 2
            || proximity.integerValue == 3 )
        {
            lockStatusLabel.text = "Tap to Unlock"
            lockIconImageView.alpha = 1.0
            outlineLayer.strokeColor = UIColor(red: 102.0/255.0, green: 153.0/255.0, blue: 102.0/255.0, alpha: 1.0).CGColor
        }
        else if ( proximity.integerValue == 1 )
        {
            lockStatusLabel.text = "Move Closer"
            lockIconImageView.alpha = 0.8
            outlineLayer.strokeColor = UIColor(red: 153.0/255.0, green: 102.0/255.0, blue: 102.0/255.0, alpha: 1.0).CGColor
        }
        else
        {
            lockStatusLabel.text = "Not in Range"
            lockIconImageView.alpha = 0.5
            outlineLayer.strokeColor = UIColor(red: 102.0/255.0, green: 102.0/255.0, blue: 102.0/255.0, alpha: 1.0).CGColor
        }
    }
    
    func startInProgressAnimation()
    {
        outlineLayer.lineDashPattern = [12, 6]
        
        let anim = CABasicAnimation(keyPath: "lineDashPhase")
        anim.fromValue = NSNumber(float: 0.0)
        anim.toValue = NSNumber(float: 36.0)
        anim.duration = 1.0
        anim.repeatCount = 10000
        outlineLayer.addAnimation(anim, forKey: "lineDashPhase")
    }
    
    func stopInProgressAnimation()
    {
        if ( outlineLayer.animationForKey("lineDashPhase") != nil )
        {
            outlineLayer.removeAnimationForKey("lineDashPhase")
        }
        outlineLayer.lineDashPattern = nil
    }
    
    func startCountdownAnimation()
    {
        let anim = CABasicAnimation(keyPath: "strokeEnd")
        anim.fromValue = NSNumber(float: 1.0)
        anim.toValue = NSNumber(float: 0.0)
        anim.duration = 6.0
        outlineLayer.addAnimation(anim, forKey: "strokeEnd")
    }
    
    func stopCountdownAnimation()
    {
        if ( outlineLayer.animationForKey("strokeEnd") != nil )
        {
            outlineLayer.removeAnimationForKey("strokeEnd")
        }
    }
    
    func showInProgress()
    {
        lockStatusLabel.text = "Connecting"
        
        startInProgressAnimation()
    }
    
    func showUnlocked()
    {
        lockStatusLabel.text = "Unlocked"
        
        stopInProgressAnimation()
        
        startCountdown()
    }
    
    func startCountdown()
    {
        lockTimerSecondsRemaining = 7
        
        startCountdownAnimation()
        
        lockTimer = NSTimer.scheduledTimerWithTimeInterval(1.0, target: self, selector: Selector("timerTicked"), userInfo: nil, repeats: true)
    }
    
    func resetUnlocked()
    {
        stopInProgressAnimation()
        stopCountdownAnimation()
        
        updateViewState()
        
        delegate?.lockCompleted!()
    }
    
    @objc func timerTicked()
    {
        lockTimerSecondsRemaining = lockTimerSecondsRemaining - 1
        
        lockStatusLabel.text = NSString(format: "%d seconds", lockTimerSecondsRemaining) as String

        if ( lockTimerSecondsRemaining <= 0 )
        {
            if ( lockTimer != nil )
            {
                lockTimer.invalidate()
                lockTimer = nil
            }
            
            lockTimerSecondsRemaining = 0
            
            resetUnlocked()
        }
    }
    
    override func awakeFromNib()
    {
        super.awakeFromNib()
        // Initialization code
        
        lockTimer = nil
        lockTimerSecondsRemaining = 0
        
        setupIconCircle()
    }
    
    private func setupIconCircle()
    {
        path = UIBezierPath(ovalInRect: lockIconImageView.bounds)
        
        maskLayer = CAShapeLayer()
        maskLayer.path = path.CGPath
        lockIconImageView.layer.mask = maskLayer
        
        let whiteOutlineLayer = CAShapeLayer()
        whiteOutlineLayer.lineWidth = 10.0
        whiteOutlineLayer.fillColor = UIColor.clearColor().CGColor
        whiteOutlineLayer.strokeColor = UIColor(red: 228.0/255.0, green: 228.0/255.0, blue: 228.0/255.0, alpha: 1.0).CGColor
        whiteOutlineLayer.path = path.CGPath
        lockIconImageView.layer.addSublayer(whiteOutlineLayer)
        
        outlineLayer = CAShapeLayer()
        outlineLayer.lineWidth = 10.0
        outlineLayer.fillColor = UIColor.clearColor().CGColor
        outlineLayer.strokeColor = UIColor.blackColor().CGColor
        outlineLayer.path = path.CGPath
        lockIconImageView.layer.addSublayer(outlineLayer)
    }

    override func setSelected(selected: Bool, animated: Bool)
    {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
}
