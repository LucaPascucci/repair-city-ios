//
//  CustomCell.swift
//  Repair City
//
//  Created by InfinityCode on 27/07/15.
//  Copyright (c) 2015 InfinityCode. All rights reserved.
//

import Foundation
import UIKit
import Parse

class CustomCell: UITableViewCell {
    
    @IBOutlet weak var priorityImage: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var distanceLabel: UILabel!
    
    var segnalation: PFObject!
    
}