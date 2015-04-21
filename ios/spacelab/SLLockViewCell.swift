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
import Darwin

class SLLockViewCell: UITableViewCell
{
    @IBOutlet weak var lockIconImageView: UIImageView!
    @IBOutlet weak var lockNameLabel: UILabel!
    @IBOutlet weak var lockStatusLabel: UILabel!
    
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
        lockIconImageView.image = UIImage(named: lock.icon)
    
        stopInProgressAnimation();
        
        updateViewState()
    }
    
    private func updateViewState()
    {
        if ( proximity.integerValue == 2
            || proximity.integerValue == 3 )
        {
            lockStatusLabel.text = "Ready to Unlock"
            lockIconImageView.alpha = 1.0
            outlineLayer.strokeColor = UIColor(red: 102.0/255.0, green: 153.0/255.0, blue: 102.0/255.0, alpha: 1.0).CGColor
        }
        else if ( proximity.integerValue == 1 )
        {
            lockStatusLabel.text = "Nearby"
            lockIconImageView.alpha = 0.8
            outlineLayer.strokeColor = UIColor(red: 153.0/255.0, green: 102.0/255.0, blue: 102.0/255.0, alpha: 1.0).CGColor
        }
        else
        {
            lockStatusLabel.text = "Not in Range"
            lockIconImageView.alpha = 0.5
            outlineLayer.strokeColor = UIColor(red: 102.0/255.0, green: 102.0/255.0, blue: 102.0/255.0, alpha: 1.0).CGColor
        }
        
        if ( lockTimer != nil )
        {
            lockTimerSecondsRemaining = 0
            
            lockTimer.invalidate()
            lockTimer = nil
        }
    }
    
    func startInProgressAnimation()
    {
        outlineLayer.lineDashPattern = [10, 6]
        
        var anim = CABasicAnimation(keyPath: "lineDashPhase")
        anim.fromValue = NSNumber(float: 0.0)
        anim.toValue = NSNumber(float: 15.0)
        anim.duration = 0.75
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
        var anim = CABasicAnimation(keyPath: "strokeEnd")
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
        lockStatusLabel.text = "Negotiating"
        
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
    }
    
    @objc func timerTicked()
    {
        lockTimerSecondsRemaining = lockTimerSecondsRemaining - 1
        
        lockStatusLabel.text = NSString(format: "%d seconds", lockTimerSecondsRemaining) as String

        if ( lockTimerSecondsRemaining <= 0 )
        {
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
