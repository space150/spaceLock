//
//  SLLockViewCell.swift
//  spacelab
//
//  Created by Shawn Roske on 3/23/15.
//  Copyright (c) 2015 space150. All rights reserved.
//

import UIKit

class SLLockViewCell: UITableViewCell
{
    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var subtitleLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
