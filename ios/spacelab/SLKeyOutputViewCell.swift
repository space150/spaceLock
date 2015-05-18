//
//  SLKeyOutputViewCell.swift
//  spacelab
//
//  Created by Shawn Roske on 5/18/15.
//  Copyright (c) 2015 space150. All rights reserved.
//

import UIKit

@objc protocol SLKeyOutputViewCellDelegate
{
    optional func doCopy(sender: AnyObject?)
}

class SLKeyOutputViewCell: UITableViewCell
{
    var delegate: SLKeyOutputViewCellDelegate?

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
    override func canBecomeFirstResponder() -> Bool
    {
        return true
    }
    
    override func canPerformAction(action: Selector, withSender sender: AnyObject?) -> Bool
    {
        return (action == "copy:")
    }
    
    override func copy(sender: AnyObject?)
    {
        delegate?.doCopy!(self)
        resignFirstResponder()
    }

}
