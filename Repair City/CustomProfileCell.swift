//
//  CustomProfileCell.swift
//  Repair City
//
//  Created by InfinityCode on 01/08/15.
//  Copyright (c) 2015 InfinityCode. All rights reserved.
//

import Foundation
import UIKit
import Parse

class CustomProfileCell: UITableViewCell {
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var priorityImage: UIImageView!
    
    var segnalation: PFObject!
    
}