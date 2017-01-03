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
    @objc optional func lockCompleted()
}

class SLLockViewCell: UITableViewCell
{
    @IBOutlet weak var lockIconImageView: UIImageView!
    @IBOutlet weak var lockNameLabel: UILabel!
    @IBOutlet weak var lockStatusLabel: UILabel!
    
    var delegate: SLLockViewCellDelegate?
    
    fileprivate var proximity: NSNumber!
    fileprivate var indexPath: IndexPath!
    fileprivate var lockTimer: Timer!
    fileprivate var lockTimerSecondsRemaining: Int!
    
    fileprivate var maskLayer: CAShapeLayer!
    fileprivate var outlineLayer: CAShapeLayer!
    fileprivate var path: UIBezierPath!
    
    func setLock(_ lock: LKLock, indexPath newIndexPath: IndexPath)
    {
        indexPath = newIndexPath
        proximity = lock.proximity
        
        lockNameLabel.text = lock.name
        lockIconImageView.image = UIImage(named: lock.icon)
        
        updateViewState()
    }
    
    fileprivate func updateViewState()
    {
        if ( proximity.intValue == 2
            || proximity.intValue == 3 )
        {
            lockStatusLabel.text = "Tap to Unlock"
            lockIconImageView.alpha = 1.0
            outlineLayer.strokeColor = UIColor(red: 102.0/255.0, green: 153.0/255.0, blue: 102.0/255.0, alpha: 1.0).cgColor
        }
        else if ( proximity.intValue == 1 )
        {
            lockStatusLabel.text = "Move Closer"
            lockIconImageView.alpha = 0.8
            outlineLayer.strokeColor = UIColor(red: 153.0/255.0, green: 102.0/255.0, blue: 102.0/255.0, alpha: 1.0).cgColor
        }
        else
        {
            lockStatusLabel.text = "Not in Range"
            lockIconImageView.alpha = 0.5
            outlineLayer.strokeColor = UIColor(red: 102.0/255.0, green: 102.0/255.0, blue: 102.0/255.0, alpha: 1.0).cgColor
        }
    }
    
    func startInProgressAnimation()
    {
        outlineLayer.lineDashPattern = [12, 6]
        
        let anim = CABasicAnimation(keyPath: "lineDashPhase")
        anim.fromValue = NSNumber(value: 0.0 as Float)
        anim.toValue = NSNumber(value: 36.0 as Float)
        anim.duration = 1.0
        anim.repeatCount = 10000
        outlineLayer.add(anim, forKey: "lineDashPhase")
    }
    
    func stopInProgressAnimation()
    {
        if ( outlineLayer.animation(forKey: "lineDashPhase") != nil )
        {
            outlineLayer.removeAnimation(forKey: "lineDashPhase")
        }
        outlineLayer.lineDashPattern = nil
    }
    
    func startCountdownAnimation()
    {
        let anim = CABasicAnimation(keyPath: "strokeEnd")
        anim.fromValue = NSNumber(value: 1.0 as Float)
        anim.toValue = NSNumber(value: 0.0 as Float)
        anim.duration = 6.0
        outlineLayer.add(anim, forKey: "strokeEnd")
    }
    
    func stopCountdownAnimation()
    {
        if ( outlineLayer.animation(forKey: "strokeEnd") != nil )
        {
            outlineLayer.removeAnimation(forKey: "strokeEnd")
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
        
        lockTimer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(SLLockViewCell.timerTicked), userInfo: nil, repeats: true)
    }
    
    func resetUnlocked()
    {
        //stopInProgressAnimation()
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
    
    fileprivate func setupIconCircle()
    {
        path = UIBezierPath(ovalIn: lockIconImageView.bounds)
        
        maskLayer = CAShapeLayer()
        maskLayer.path = path.cgPath
        lockIconImageView.layer.mask = maskLayer
        
        let whiteOutlineLayer = CAShapeLayer()
        whiteOutlineLayer.lineWidth = 10.0
        whiteOutlineLayer.fillColor = UIColor.clear.cgColor
        whiteOutlineLayer.strokeColor = UIColor(red: 228.0/255.0, green: 228.0/255.0, blue: 228.0/255.0, alpha: 1.0).cgColor
        whiteOutlineLayer.path = path.cgPath
        lockIconImageView.layer.addSublayer(whiteOutlineLayer)
        
        outlineLayer = CAShapeLayer()
        outlineLayer.lineWidth = 10.0
        outlineLayer.fillColor = UIColor.clear.cgColor
        outlineLayer.strokeColor = UIColor.black.cgColor
        outlineLayer.path = path.cgPath
        lockIconImageView.layer.addSublayer(outlineLayer)
    }

    override func setSelected(_ selected: Bool, animated: Bool)
    {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
}
