//
//  CustomPageViewController.swift
//  Repair City
//
//  Created by InfinityCode on 08/08/15.
//  Copyright (c) 2015 InfinityCode. All rights reserved.
//

import Foundation
import UIKit

class CustomPageViewController: UIViewController , BWWalkthroughPage {
    
    @IBOutlet var imageView:UIImageView?
    @IBOutlet var titleLabel:UILabel?
    @IBOutlet var textLabel:UILabel?
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    // MARK: BWWalkThroughPage protocol
    
    func walkthroughDidScroll(position: CGFloat, offset: CGFloat) {
        
        var transform = CATransform3DIdentity
        var mx:CGFloat = (1.0 - offset) * 100
        titleLabel?.layer.transform = CATransform3DTranslate(transform, mx * 3, 0,  0 )
        textLabel?.layer.transform = CATransform3DTranslate(transform, mx * 1, 0,  0 )
        imageView?.layer.transform = CATransform3DTranslate(transform, mx * 5, 0,  0 )
    }
    
}
