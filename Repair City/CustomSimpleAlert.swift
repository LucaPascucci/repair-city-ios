//
//  CustomSimpleAlert.swift
//  Repair City
//
//  Created by Filippo Nicolini on 10/08/15.
//  Copyright (c) 2015 InfinityCode. All rights reserved.
//

import Foundation
import SimpleAlert


class CustomSimpleAlert: SimpleAlert.Controller {
    override func addTextFieldWithConfigurationHandler(configurationHandler: ((UITextField!) -> Void)? = nil) {
        super.addTextFieldWithConfigurationHandler() { textField in
            textField.frame.size.height = 20
            textField.backgroundColor = nil
            textField.layer.borderColor = nil
            textField.layer.borderWidth = 0
            
            configurationHandler?(textField)
        }
    }
    
    override func configurButton(style :SimpleAlert.Action.Style, forButton button: UIButton) {
        super.configurButton(style, forButton: button)
        
        if let font = button.titleLabel?.font {
            switch style {
            case .OK:
                //button.titleLabel?.font = UIFont.boldSystemFontOfSize(20)
                button.setTitleColor(GlobalsMethods().UIColorFromRGB(0x007AFF), forState: .Normal)
            case .Cancel:
                //button.backgroundColor = UIColor.darkGrayColor()
                button.setTitleColor(GlobalsMethods().UIColorFromRGB(0xFF0000), forState: .Normal)
            case .Default:
                button.titleLabel?.font = UIFont.boldSystemFontOfSize(20)
                button.setTitleColor(GlobalsMethods().UIColorFromRGB(0x00796B), forState: .Normal)
            default:
                break
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        configContentView = { [weak self] view in
            if let view = view as? SimpleAlert.ContentView {
                view.titleLabel.textColor = UIColor.lightGrayColor()
                view.titleLabel.font = UIFont.boldSystemFontOfSize(30)
                view.messageLabel.textColor = UIColor.lightGrayColor()
                view.messageLabel.font = UIFont.boldSystemFontOfSize(16)
                view.textBackgroundView.layer.cornerRadius = 3.0
                view.textBackgroundView.clipsToBounds = true
            }
        }
    }
}