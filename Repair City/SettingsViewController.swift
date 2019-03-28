//
//  SettingsViewController.swift
//  Repair City
//
//  Created by InfinityCode on 30/07/15.
//  Copyright (c) 2015 InfinityCode. All rights reserved.
//

import Foundation
import UIKit
import Social
import AddressBookUI
import MessageUI


class SettingsViewController : UITableViewController, UITableViewDelegate, UITableViewDataSource, ABPeoplePickerNavigationControllerDelegate, MFMailComposeViewControllerDelegate, MFMessageComposeViewControllerDelegate, BWWalkthroughViewControllerDelegate {
    
    //MARK: - @IBOutlet
    @IBOutlet weak var rangeSlider: UISlider!
    @IBOutlet weak var rangeLabel: UILabel!
    @IBOutlet var table: UITableView!
    
    //MARK: - Variabili
    var selectedContact: String!
    var pickerPeople: ABPeoplePickerNavigationController!
    var pickerSMS: MFMessageComposeViewController!
    var pickerMail: MFMailComposeViewController!
    var walkthrough: BWWalkthroughViewController!
    var selectedTypeContacts: String!
    var rangeValue: Int!
    let indexView = 4
    let addressBookRef: ABAddressBook = ABAddressBookCreateWithOptions(nil, nil).takeRetainedValue()
    let segueIdentifier = "FromSettingsToInfo"
    
    //MARK:
    override func viewDidLoad() {
        super.viewDidLoad()
        rangeSlider.value = Float(GlobalsMethods().getSegnalationRangeOnNSUserDefaults(GlobalVariables.keyPreferencesSegnalationRange))
        rangeLabel.text = "\(Int(rangeSlider.value)) km"
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        //controllo connessione ad internet
        if (GlobalsMethods().isConnectedToNetwork()){
            if (!GlobalsMethods().getBoolOnNSUserDefaults(GlobalVariables.keyPreferencesDispatchActive)){
                GlobalsMethods().writeOnNSUserDefaults(GlobalVariables.keyPreferencesDispatchActive, value: true)
                //crea un thread async
                dispatch_async(dispatch_get_global_queue(Int(QOS_CLASS_USER_INITIATED.value), 0)) {
                    //operazioni che esegue il thread
                    Utente().syncingLocalChanges()
                    Segnalazione().syncingLocalChanges()
                    dispatch_async(dispatch_get_main_queue()) {
                        GlobalsMethods().writeOnNSUserDefaults(GlobalVariables.keyPreferencesDispatchActive, value: false)
                    }
                }
            }
        }
        GlobalsMethods().writeOnNSUserDefaults(GlobalVariables.keyPreferencesPreviousView, value: indexView)
        rangeValue = GlobalsMethods().getSegnalationRangeOnNSUserDefaults(GlobalVariables.keyPreferencesSegnalationRange)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if (segue.identifier == segueIdentifier) {
            var destViewController: InfoViewController = segue.destinationViewController as! InfoViewController
            destViewController.hidesBottomBarWhenPushed = true
        }
    }
    
    //MARK: - @IBAction
    @IBAction func valueChanged(sender: UISlider) {
        var currentValue = Int(rangeSlider.value)
        rangeLabel.text = "\(currentValue) km"
        GlobalsMethods().writeOnNSUserDefaults(GlobalVariables.keyPreferencesSegnalationRange, value: currentValue)
        if (rangeValue < currentValue){
            GlobalsMethods().writeOnNSUserDefaults(GlobalVariables.keyPreferencesForcedSync, value: true)
        }else{
            GlobalsMethods().writeOnNSUserDefaults(GlobalVariables.keyPreferencesForcedSync, value: false)
        }
    }
    
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        tableView.deselectRowAtIndexPath(indexPath, animated: true)
        if (indexPath.section == 1 && indexPath.row == 0) {
            self.shareFacebook()
        } else if (indexPath.section == 1 && indexPath.row == 1) {
            self.shareTwitter()
        } else if (indexPath.section == 1 && indexPath.row == 2) {
            if (GlobalsMethods().getAddressBookStatus()) {
                selectedTypeContacts = "mail"
                var err: Unmanaged<CFError>? = nil
                
                ABAddressBookRequestAccessWithCompletion(addressBookRef) {
                    (granted: Bool, error: CFError!) in
                    dispatch_async(dispatch_get_main_queue()) {
                        if (granted) {
                            self.showContacts()
                        }
                    }
                }
            }
        } else if (indexPath.section == 1 && indexPath.row == 3) {
            if (GlobalsMethods().getAddressBookStatus()){
                selectedTypeContacts = "sms"
                var err: Unmanaged<CFError>? = nil
                
                ABAddressBookRequestAccessWithCompletion(addressBookRef) {
                    (granted: Bool, error: CFError!) in
                    dispatch_async(dispatch_get_main_queue()) {
                        if (granted) {
                            self.showContacts()
                        }
                    }
                }
            }
        } else if (indexPath.section == 2 && indexPath.row == 0) {
            showWalkthrough()
        }
    }
    
    //delegate alla view dei contatti per la selezione
    func showContacts() {
        pickerPeople = ABPeoplePickerNavigationController()
        pickerPeople.peoplePickerDelegate = self
        switch (selectedTypeContacts) {
        case "mail":
            pickerPeople.displayedProperties = [NSNumber(int: kABPersonEmailProperty)]
            break
        case "sms":
            pickerPeople.displayedProperties = [NSNumber(int: kABPersonPhoneProperty)]
            break
        default:
            break
        }
        presentViewController(pickerPeople, animated: true, completion: nil)
    }
    
    //picker per la mail dei contatti
    func peoplePickerNavigationController(peoplePicker: ABPeoplePickerNavigationController!, didSelectPerson person: ABRecordRef!, property: ABPropertyID, identifier: ABMultiValueIdentifier) {
        
        let multiValue: ABMultiValueRef = ABRecordCopyValue(person, property).takeUnretainedValue() as ABMultiValueRef
        let index = ABMultiValueGetIndexForIdentifier(multiValue, identifier)
        let phoneOrMail = ABMultiValueCopyValueAtIndex(multiValue, index).takeUnretainedValue() as! String
        
        selectedContact = phoneOrMail
        
        switch (selectedTypeContacts) {
        case "mail":
            sendMail()
            break
        case "sms":
            sendSMS()
            break
        default:
            break
        }
    }
    
    //dismiss people picker controller
    func peoplePickerNavigationControllerDidCancel(peoplePicker: ABPeoplePickerNavigationController!) {
        dismissViewControllerAnimated(true, completion: nil)
    }
    
    //delegate per mandare SMS
    func sendSMS() {
        //call dismiss people picker
        peoplePickerNavigationControllerDidCancel(pickerPeople)
        
        pickerSMS = MFMessageComposeViewController()
        pickerSMS.messageComposeDelegate = self;
        var array: [String] = [selectedContact]
        pickerSMS.recipients = array
        pickerSMS.body = "Prova Repair City per il tuo smartphone. Disponibile per iOS e Android."
        
        presentViewController(pickerSMS, animated: false, completion: nil)
    }
    
    //dismiss SMS
    func messageComposeViewController(controller: MFMessageComposeViewController!, didFinishWithResult result: MessageComposeResult) {
        dismissViewControllerAnimated(true, completion: nil)
    }
    
    //delegate alla mail per poter inviare la mail
    func sendMail() {
        //call dismiss peolple picker
        peoplePickerNavigationControllerDidCancel(pickerPeople)
        
        pickerMail = MFMailComposeViewController()
        pickerMail.mailComposeDelegate = self
        var array: [String] = [selectedContact]
        pickerMail.setToRecipients(array)
        pickerMail.setSubject("Repair City")
        pickerMail.setMessageBody("Ciao,<br><br>ho appena scaricato Repair City sul mio iPhone.<br>È un servizio per segnalare problemi nella tua città.<br>Disponibile per iOS e Android.", isHTML: true)
        
        presentViewController(pickerMail, animated: true, completion: nil)
    }
    
    //dismiss mail controller
    func mailComposeController(controller: MFMailComposeViewController!, didFinishWithResult result: MFMailComposeResult, error: NSError!) {
        dismissViewControllerAnimated(true, completion: nil)
    }
    
    //MARK: - Condivisione sui social
    func shareFacebook() {
        if(SLComposeViewController.isAvailableForServiceType(SLServiceTypeFacebook)) {
            var facebookPost :SLComposeViewController = SLComposeViewController(forServiceType: SLServiceTypeFacebook)
            
            facebookPost.completionHandler = {
                result -> Void in
                
                var getResult = result as SLComposeViewControllerResult;
                switch(getResult.rawValue) {
                case SLComposeViewControllerResult.Cancelled.rawValue: println("Condivisione cancellata")
                case SLComposeViewControllerResult.Done.rawValue: println("Condiviso")
                default: println("Errore!")
                }
                self.dismissViewControllerAnimated(true, completion: nil)
            }
            facebookPost.addImage(UIImage(named: "AppIcon.png"))
            
            self.presentViewController(facebookPost, animated: true, completion: nil)
            
        } else {
            SCLAlertView().showWarning("Accesso non effettuato", subTitle: "Accedere a Facebook in\nImpostazioni -> Facebook\nper condividere")
        }
    }
    
    func shareTwitter() {
        if SLComposeViewController.isAvailableForServiceType(SLServiceTypeTwitter) {
            
            var tweetShare:SLComposeViewController = SLComposeViewController(forServiceType: SLServiceTypeTwitter)
            tweetShare.setInitialText("Prova Repair City per il tuo smartphone!")
            tweetShare.addImage(UIImage(named: "AppIcon.png"))
            self.presentViewController(tweetShare, animated: true, completion: nil)
            
        } else {
            SCLAlertView().showWarning("Accesso non effettuato", subTitle: "Accedere a Twitter in\nImpostazioni -> Twitter\nper condividere")
        }
    }
    
    func showWalkthrough() {
        
        let stb = UIStoryboard(name: "Walkthrough", bundle: nil)
        walkthrough = stb.instantiateViewControllerWithIdentifier("Master") as! BWWalkthroughViewController
        
        let page_1 = stb.instantiateViewControllerWithIdentifier("Pagina1") as! UIViewController
        let page_2 = stb.instantiateViewControllerWithIdentifier("Pagina2") as! UIViewController
        let page_3 = stb.instantiateViewControllerWithIdentifier("Pagina3") as! UIViewController
        let page_4 = stb.instantiateViewControllerWithIdentifier("Pagina4") as! UIViewController
        let page_5 = stb.instantiateViewControllerWithIdentifier("Pagina5") as! UIViewController
        let page_6 = stb.instantiateViewControllerWithIdentifier("Pagina6") as! UIViewController
        
        //Collego le pagine al master
        walkthrough.delegate = self
        walkthrough.addViewController(page_1)
        walkthrough.addViewController(page_2)
        walkthrough.addViewController(page_3)
        walkthrough.addViewController(page_4)
        walkthrough.addViewController(page_5)
        walkthrough.addViewController(page_6)
        
        //Visualizzo il master
        self.presentViewController(walkthrough, animated: true, completion: nil)
    }
    
    // MARK: - Walkthrough delegate
    func walkthroughPageDidChange(pageNumber: Int) {
        if (pageNumber == 0){
            walkthrough.prevButton?.hidden = true
        }
        if (pageNumber == 5){
            walkthrough.closeButton?.hidden = false
        }else{
            walkthrough.closeButton?.hidden = true
        }
    }
    
    func walkthroughCloseButtonPressed() {
        self.dismissViewControllerAnimated(true, completion: nil)
    }
}