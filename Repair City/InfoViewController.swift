//
//  InfoViewController.swift
//  Repair City
//
//  Created by InfinityCode on 06/08/15.
//  Copyright (c) 2015 InfinityCode. All rights reserved.
//

import Foundation
import UIKit
import MessageUI
import Parse

class InfoViewController : UITableViewController, UITableViewDelegate, UITableViewDataSource, MFMailComposeViewControllerDelegate {
    
    var userName: String!
    
    //MARK:
    override func viewDidLoad() {
        super.viewDidLoad()
        self.tableView.contentInset = UIEdgeInsetsMake(-1.0, 0.0, 0.0, 0.0);
        var keyUserLogged = GlobalsMethods().getUserOnNSUserDefaults(GlobalVariables.keyPreferencesFB)
        dispatch_async(dispatch_get_global_queue(Int(QOS_CLASS_USER_INITIATED.value), 0)) {
            var userLogged = Utente().getLocalUserObject(keyUserLogged!) as PFObject!
            dispatch_async(dispatch_get_main_queue()) {
                self.userName = userLogged[Utente.name] as! String
            }
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        tableView.deselectRowAtIndexPath(indexPath, animated: true)
        if (indexPath.section == 1 && indexPath.row == 0) {
            self.sendMail()
        }
    }
    
    override func tableView(tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if (section == 0) {
            return 1.0
        }
        return 10.0
    }
    
    override func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return nil
    }
    
    func sendMail() {
        var pickerMail = MFMailComposeViewController()
        pickerMail.mailComposeDelegate = self
        var array: [String] = ["infinitycode.dev@gmail.com"]
        pickerMail.setToRecipients(array)
        pickerMail.setSubject("Messagio da \(userName)")
        pickerMail.setMessageBody("Salve Infinity Code,<br><br>sto utilizzando la vostra applicazione Repair City e...", isHTML: true)
        
        presentViewController(pickerMail, animated: true, completion: nil)
    }
    
    func mailComposeController(controller: MFMailComposeViewController!, didFinishWithResult result: MFMailComposeResult, error: NSError!) {
        dismissViewControllerAnimated(true, completion: nil)
    }
    
}