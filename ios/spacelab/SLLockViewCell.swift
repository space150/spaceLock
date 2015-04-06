//
//  SLLockViewCell.swift
//  spacelab
//
//  Created by Shawn Roske on 3/23/15.
//  Copyright (c) 2015 space150. All rights reserved.
//

import UIKit
import QuartzCore

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
    var indexPath: NSIndexPath!
    var delegate: SLLockViewCellDelegate?
    
    override func awakeFromNib()
    {
        super.awakeFromNib()
        // Initialization code
        
        backgroundColor = UIColor.clearColor()
        
        insetBackgroundView.layer.cornerRadius = 10
        insetBackgroundView.layer.masksToBounds = true
    }

    override func setSelected(selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

    @IBAction func doUnlock(sender: AnyObject)
    {
        delegate?.performUnlock!(indexPath)
    }
}
