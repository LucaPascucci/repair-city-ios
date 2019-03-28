//
//  ProfileViewController.swift
//  Repair City
//
//  Created by InfinityCode on 24/07/15.
//  Copyright (c) 2015 InfinityCode. All rights reserved.
//

import Foundation
import UIKit
import FBSDKCoreKit
import FBSDKLoginKit
import Social
import Parse

class ProfileViewController: UIViewController, UINavigationControllerDelegate, CLLocationManagerDelegate, UITableViewDataSource, UITableViewDelegate {
    
    //MARK: - @IBOutlet
    @IBOutlet weak var profileImageView: UIImageView!
    @IBOutlet weak var userNameLabel: UILabel!
    @IBOutlet weak var likeLabel: UILabel!
    @IBOutlet weak var notLikeLabel: UILabel!
    @IBOutlet weak var segmentedControl: UISegmentedControl!
    @IBOutlet weak var tableView: UITableView!
    
    //MARK: - Variabili
    var currUser: PFObject!
    var userSegnalations: [PFObject] = []
    var userSegnalationsSolved: [PFObject] = []
    var userSegnalationsUnsolved: [PFObject] = []
    var locationManager = CLLocationManager()
    var locationValue: CLLocationCoordinate2D!
    
    let cellIdentifier = "profileCell"
    let detailSegueIdentifier = "FromProfileToDetail"
    let indexView = 3
    
    var dictObjectDownload = Dictionary<String, PFObject> ()
    var dictStartedDownload = Dictionary<String, Int> ()
    
    //variabili per la gestione dei casi di tap&scroll per caricare i dati in background
    var startDec = false
    var endDec = false
    var startDrag = false
    var endDrag = false
    
    //MARK:
    override func viewDidLoad() {
        super.viewDidLoad()
        
        locationManager = CLLocationManager()
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.startUpdatingLocation()
        
        profileImageView.layer.cornerRadius = 50.0
        profileImageView.clipsToBounds = true
        
        segmentedControl.selectedSegmentIndex = 0
        
        //da nil
        //var indexes : [CustomProfileCell] = tableView.visibleCells() as! [CustomProfileCell]
        //var indexes : [NSIndexPath] = tableView.indexPathsForVisibleRows() as! [NSIndexPath]
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        if (GlobalsMethods().getBoolOnNSUserDefaults(GlobalVariables.keyPreferencesForcedSync)) {
            if (GlobalsMethods().isConnectedToNetwork()) {
                if (GlobalsMethods().getGPSAutorizationStatus()) {
                    var waitAlert = SCLAlertView().showWait("Aggiornamento", subTitle: "Sto aggiornando i dati con le nuove impostazioni", duration: 0.0, closeButtonTitle: "", colorStyle: 0x00796B, colorTextButton: 0x4D4D4D)
                    dispatch_async(dispatch_get_global_queue(Int(QOS_CLASS_USER_INITIATED.value), 0)) {
                        
                        self.syncAllWithOnline()
                        
                        self.segmentedControlChanged(self.segmentedControl)
                        
                        dispatch_async(dispatch_get_main_queue()) {
                            self.tableView.reloadData()
                            GlobalsMethods().writeOnNSUserDefaults(GlobalVariables.keyPreferencesForcedSync, value: false)
                            waitAlert.close()
                        }
                    }
                }
            } else {
                SCLAlertView().showError("Connessione assente", subTitle: "Controlla che il tuo dispositivo sia connesso a internet")
            }
            dispatch_async(dispatch_get_global_queue(Int(QOS_CLASS_USER_INITIATED.value), 0)) {
                
                self.currUser = Utente().getLocalUserObject(GlobalsMethods().getUserOnNSUserDefaults(GlobalVariables.keyPreferencesFB)!)!
                let profileImageFile = self.currUser[Utente.profilePhoto] as! PFFile
                var profileImageData = profileImageFile.getData()
                
                var like = Valutazione().getNumberOfLikeOrDislikesOfAnUser(self.currUser, likeOrNotLike: 1)
                var notLike = Valutazione().getNumberOfLikeOrDislikesOfAnUser(self.currUser, likeOrNotLike: -1)
                
                dispatch_async(dispatch_get_main_queue()) {
                    self.userNameLabel.text = self.currUser[Utente.name] as? String
                    self.profileImageView.image = UIImage(data: profileImageData!)
                    self.likeLabel.text = "\(like)"
                    self.notLikeLabel.text = "\(notLike)"
                }
            }
            
        } else {
            dispatch_async(dispatch_get_global_queue(Int(QOS_CLASS_USER_INITIATED.value), 0)) {
                self.currUser = Utente().getLocalUserObject(GlobalsMethods().getUserOnNSUserDefaults(GlobalVariables.keyPreferencesFB)!)!
                let profileImageFile = self.currUser[Utente.profilePhoto] as! PFFile
                var profileImageData = profileImageFile.getData()
                
                self.segmentedControlChanged(self.segmentedControl)
                
                var like = Valutazione().getNumberOfLikeOrDislikesOfAnUser(self.currUser, likeOrNotLike: 1)
                var notLike = Valutazione().getNumberOfLikeOrDislikesOfAnUser(self.currUser, likeOrNotLike: -1)
                dispatch_async(dispatch_get_main_queue()) {
                    self.userNameLabel.text = self.currUser[Utente.name] as? String
                    self.profileImageView.image = UIImage(data: profileImageData!)
                    self.likeLabel.text = "\(like)"
                    self.notLikeLabel.text = "\(notLike)"
                    self.tableView.reloadData()
                }
            }
        }
        
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
    }
    
    // precaricamento dei dati per il detail
    override func viewDidAppear(animated: Bool) {
        var visibleCells = tableView.visibleCells()
        for cell in visibleCells {
            var c: CustomProfileCell = cell as! CustomProfileCell
            if (dictObjectDownload.indexForKey(c.segnalation.objectId!) == nil) {
                var str = c.segnalation.objectId! as String
                dictObjectDownload[str] = cell.segnalation as PFObject
            }
        }
        //inizio download
        if (dictObjectDownload.count > dictStartedDownload.count) {
            asyncDownload()
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if (segue.identifier == detailSegueIdentifier) {
            if let destination = segue.destinationViewController as? DetailViewController {
                
                if let segnalationIndex = tableView.indexPathForSelectedRow()?.row {
                    var segnalation: PFObject!
                    switch (segmentedControl.selectedSegmentIndex) {
                    case 0:
                        segnalation = userSegnalations[segnalationIndex] as PFObject
                        break
                    case 1:
                        segnalation = userSegnalationsSolved[segnalationIndex] as PFObject
                        break
                    case 2:
                        segnalation = userSegnalationsUnsolved[segnalationIndex] as PFObject
                        break
                    default:
                        break
                    }
                    destination.segnalationObject = segnalation
                    destination.showSolve = segnalation[Segnalazione.solved] as! Bool
                }
            }
        }
    }
    
    //MARK: - @IBAction
    @IBAction func logout(sender: AnyObject) {
        if (FBSDKAccessToken.currentAccessToken() != nil){
            var fbLoginManager : FBSDKLoginManager = FBSDKLoginManager()
            fbLoginManager.logOut()
            GlobalsMethods().removeOnNSUserDefaults(GlobalVariables.keyPreferencesFB)
            navigateToLogin()
        }
    }
    
    @IBAction func segmentedControlChanged(sender: UISegmentedControl) {
        switch (segmentedControl.selectedSegmentIndex) {
        case 0:
            dispatch_async(dispatch_get_global_queue(Int(QOS_CLASS_USER_INITIATED.value), 0)) {
                self.userSegnalations = Segnalazione().getSegnalationsOfAnUser(self.currUser, solved: nil)
                dispatch_async(dispatch_get_main_queue()) {
                    self.tableView.reloadData()
                }
            }
            break
        case 1:
            dispatch_async(dispatch_get_global_queue(Int(QOS_CLASS_USER_INITIATED.value), 0)) {
                self.userSegnalationsSolved = Segnalazione().getSegnalationsOfAnUser(self.currUser, solved: true)
                dispatch_async(dispatch_get_main_queue()) {
                    self.tableView.reloadData()
                }
            }
            break
        case 2:
            dispatch_async(dispatch_get_global_queue(Int(QOS_CLASS_USER_INITIATED.value), 0)) {
                self.userSegnalationsUnsolved = Segnalazione().getSegnalationsOfAnUser(self.currUser, solved: false)
                dispatch_async(dispatch_get_main_queue()) {
                    self.tableView.reloadData()
                }
            }
            break
        default:
            break
        }
    }
    
    @IBAction func refreshOnline(sender: AnyObject) {
        if (GlobalsMethods().isConnectedToNetwork()){
            updateListAndValutationOnline()
        }else{
            SCLAlertView().showError("Connessione Assente", subTitle: "Controlla che il tuo dispositivo sia connesso ad internet")
        }
    }
    
    // MARK: - Funzioni per gestione tab&scroll
    func scrollViewWillBeginDecelerating(scrollView: UIScrollView) {
        endDrag = false
        startDec = true
    }
    
    func scrollViewDidEndDecelerating(scrollView: UIScrollView) {
        startDec = false
        endDec = true
        if (!startDrag) {
            if (endDrag) {
                //case 2
                var visibleCells = tableView.visibleCells()
                for cell in visibleCells {
                    var c: CustomProfileCell = cell as! CustomProfileCell
                    if (dictObjectDownload.indexForKey(c.segnalation.objectId!) == nil) {
                        var str = c.segnalation.objectId! as String
                        dictObjectDownload[str] = cell.segnalation as PFObject
                    }
                }
            } else {
                //case 1
                var visibleCells = tableView.visibleCells()
                for cell in visibleCells {
                    var c: CustomProfileCell = cell as! CustomProfileCell
                    if (dictObjectDownload.indexForKey(c.segnalation.objectId!) == nil) {
                        var str = c.segnalation.objectId! as String
                        dictObjectDownload[str] = cell.segnalation as PFObject
                    }
                }
            }
            //inizio download
            if (dictObjectDownload.count > dictStartedDownload.count) {
                asyncDownload()
            }
            
        }
    }
    
    func scrollViewWillBeginDragging(scrollView: UIScrollView) {
        startDrag = true
        endDec = false
    }
    
    func scrollViewDidEndDragging(scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        startDrag = false
        endDrag = true
        /*if (!startDec && endDrag) {
        //case 3
        println("CASO 3")
        }*/
    }
    
    //MARK: - Riempimento TableView
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch (segmentedControl.selectedSegmentIndex) {
        case 0:
            return userSegnalations.count
        case 1:
            return userSegnalationsSolved.count
        case 2:
            return userSegnalationsUnsolved.count
        default:
            return userSegnalations.count
        }
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        var cell: CustomProfileCell = tableView.dequeueReusableCellWithIdentifier(cellIdentifier) as! CustomProfileCell
        var segnalation: PFObject!
        switch (segmentedControl.selectedSegmentIndex) {
        case 0:
            segnalation = userSegnalations[indexPath.row] as PFObject
            break
        case 1:
            segnalation = userSegnalationsSolved[indexPath.row] as PFObject
            break
        case 2:
            segnalation = userSegnalationsUnsolved[indexPath.row] as PFObject
            break
        default:
            break
        }
        cell.titleLabel.text = segnalation[Segnalazione.title] as? String
        cell.descriptionLabel.text = segnalation[Segnalazione.description] as? String
        
        cell.segnalation = segnalation
        
        switch (segnalation[Segnalazione.priority] as! Int) {
        case 1:
            cell.priorityImage.image = UIImage(named: "YellowCircle.png")
            break
        case 2:
            cell.priorityImage.image = UIImage(named: "OrangeCircle.png")
            break
        case 3:
            cell.priorityImage.image = UIImage(named: "RedCircle.png")
            break
        default:
            cell.priorityImage.image = UIImage(named: "YellowCircle.png")
            break
        }
        
        return cell
    }
    
    func tableView(tableView: UITableView, editActionsForRowAtIndexPath indexPath: NSIndexPath) -> [AnyObject]? {
        let solved = UITableViewRowAction(style: .Normal, title: "Risolta") { action, index in
            var segnalation: PFObject!
            segnalation = self.userSegnalationsUnsolved[indexPath.row] as PFObject
            if (GlobalsMethods().isConnectedToNetwork()){
                dispatch_async(dispatch_get_global_queue(Int(QOS_CLASS_USER_INITIATED.value), 0)) {
                    Segnalazione().updateSolved(segnalation.objectId!, solved: true)
                    dispatch_async(dispatch_get_main_queue()) {
                        self.userSegnalationsUnsolved.removeAtIndex(indexPath.row)
                        tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: UITableViewRowAnimation.Left)
                        tableView.reloadData()
                    }
                }
            } else {
                SCLAlertView().showError("Connessione Assente", subTitle: "Controlla che il tuo dispositivo sia connesso a internet")
            }
        }
        solved.backgroundColor = GlobalsMethods().UIColorFromRGB(0x00796B)
        
        let unsolved = UITableViewRowAction(style: .Normal, title: "Non Risolta") { action, index in
            var segnalation: PFObject!
            segnalation = self.userSegnalationsSolved[indexPath.row] as PFObject
            if (GlobalsMethods().isConnectedToNetwork()){
                dispatch_async(dispatch_get_global_queue(Int(QOS_CLASS_USER_INITIATED.value), 0)) {
                    Segnalazione().updateSolved(segnalation.objectId!, solved: false)
                    dispatch_async(dispatch_get_main_queue()) {
                        self.userSegnalationsSolved.removeAtIndex(indexPath.row)
                        tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: UITableViewRowAnimation.Left)
                        tableView.reloadData()
                    }
                }
            } else {
                SCLAlertView().showError("Connessione Assente", subTitle: "Controlla che il tuo dispositivo sia connesso a internet")
            }
        }
        unsolved.backgroundColor = GlobalsMethods().UIColorFromRGB(0xD32F2F)
        
        switch (segmentedControl.selectedSegmentIndex) {
        case 1:
            return [unsolved]
        default:
            return [solved]
        }
    }
    
    func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        switch (segmentedControl.selectedSegmentIndex) {
        case 0:
            return false
        default:
            return true
        }
    }
    
    func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        
    }
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        tableView.deselectRowAtIndexPath(indexPath, animated: true)
    }
    
    
    
    // MARK: - Ritorno alla schermata di Login
    func navigateToLogin(){
        let storyBoard : UIStoryboard = UIStoryboard(name: "Main", bundle:nil)
        let nextViewController = storyBoard.instantiateViewControllerWithIdentifier("LoginView") as! UIViewController
        self.presentViewController(nextViewController, animated:true, completion:nil)
        
    }

    //MARK: - Funzione che aggiorna le segnalazioni e le valutazioni con online da bottone
    func updateListAndValutationOnline(){
        if (GlobalsMethods().getGPSAutorizationStatus()){
            if (locationManager.location != nil){
                dispatch_async(dispatch_get_global_queue(Int(QOS_CLASS_USER_INITIATED.value), 0)) {
                    var arraySegnalations = Segnalazione().updateWithOnline(PFGeoPoint(location: self.locationManager.location)) as [PFObject]
                    Valutazione().updateWithOnline(arraySegnalations)
                    switch (self.segmentedControl.selectedSegmentIndex) {
                    case 0:
                        self.userSegnalations = Segnalazione().getSegnalationsOfAnUser(self.currUser, solved: nil)
                        break
                    case 1:
                        self.userSegnalationsSolved = Segnalazione().getSegnalationsOfAnUser(self.currUser, solved: true)
                        break
                    case 2:
                        self.userSegnalationsUnsolved = Segnalazione().getSegnalationsOfAnUser(self.currUser, solved: false)
                        break
                    default:
                        break
                    }
                    var like = Valutazione().getNumberOfLikeOrDislikesOfAnUser(self.currUser, likeOrNotLike: 1)
                    var notLike = Valutazione().getNumberOfLikeOrDislikesOfAnUser(self.currUser, likeOrNotLike: -1)
                    dispatch_async(dispatch_get_main_queue()) {
                        self.likeLabel.text = "\(like)"
                        self.notLikeLabel.text = "\(notLike)"
                        self.tableView.reloadData()
                    }
                    
                }
            }
        }
    }
    
    //MARK: - Funzione che preso un'array di stringhe toglie i duplicati
    func uniq<S : SequenceType, T : Hashable where S.Generator.Element == T>(source: S) -> [T] {
        var buffer = [T]()
        var added = Set<T>()
        for elem in source {
            if !added.contains(elem) {
                buffer.append(elem)
                added.insert(elem)
            }
        }
        return buffer
    }
    
    //MARK: - Funzione che sincronizza tutti i dati con online
    func syncAllWithOnline (){
        if (locationManager.location != nil){
            var arraySegnalations = Segnalazione().updateWithOnline(PFGeoPoint(location: locationManager.location))
            var arrayUsers: [String] = []
            for segnalation in arraySegnalations {
                var user = segnalation[Segnalazione.user] as! PFObject
                arrayUsers.append(user.objectId!)
            }
            let arrayUsersUnique = uniq(arrayUsers)
            
            Utente().updateWithOnline(arrayUsersUnique)
            Valutazione().updateWithOnline(arraySegnalations)
        }
    }
    
    //MARK: - Precaricamento dati visibili
    func asyncDownload() {
        dispatch_async(dispatch_get_global_queue(Int(QOS_CLASS_USER_INITIATED.value), 0)) {
            //scarico i dati
            var userIdArray: [String] = []
            var segnArray: [PFObject] = []
            for segnalazione in self.dictObjectDownload {
                if (self.dictStartedDownload.indexForKey(segnalazione.0) == nil) { //devo far partire il download
                    
                    //prendo l'oggetto segnalazione
                    var objectSegnalazione: PFObject = self.dictObjectDownload[segnalazione.0]!
                    
                    //prendo l'utente e scarico la sua immagine del profilo
                    var user: PFObject = objectSegnalazione[Segnalazione.user] as! PFObject
                    
                    //controllo se l'utente è già in locale altrimenti lo salvo
                    if (!Utente().checkUserExistLocal(user.objectId!)) {
                        userIdArray.append(user.objectId!)
                    }
                    
                    //aggiungo la valutazione all'array
                    segnArray.append(objectSegnalazione)
                    self.dictStartedDownload[objectSegnalazione.objectId!] = 1
                } else { //il download di questo oggetto è già iniziato
                }
            }
            
            //controllo connessione ad internet
            if (GlobalsMethods().isConnectedToNetwork()){
                //crea un thread async
                dispatch_async(dispatch_get_global_queue(Int(QOS_CLASS_USER_INITIATED.value), 0)) {
                    //scarico gli utenti e le valutazioni che non ho in locale
                    if (userIdArray.count > 0) {
                        let arrayUsersUnique = self.uniq(userIdArray)
                        var users: [PFObject] = Utente().updateWithOnline(arrayUsersUnique)
                        for user in users {
                            let userImageFile = user[Utente.profilePhoto] as! PFFile
                            var userImageData = userImageFile.getData()
                        }
                    }
                    if (segnArray.count > 0) {
                        Valutazione().updateWithOnline(segnArray)
                    }
                    dispatch_async(dispatch_get_main_queue()) {
                    }
                }
            }
        }
    }
}
