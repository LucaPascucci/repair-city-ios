//
//  ListViewController.swift
//  Repair City
//
//  Created by InfinityCode on 27/07/15.
//  Copyright (c) 2015 InfinityCode. All rights reserved.
//

import Foundation
import UIKit
import MapKit
import Parse

class ListViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, CLLocationManagerDelegate, UIScrollViewDelegate {
    
    //MARK: - IBOutlet
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var filterSegmentedControl: UISegmentedControl!
    
    //MARK: - Variabili
    var refreshControl = UIRefreshControl()
    var segnalationArray: [PFObject]!
    var locationValue: CLLocation!
    var dictObjectDownload = Dictionary<String, PFObject> ()
    var dictStartedDownload = Dictionary<String, Int> ()
    
    //variabili per la gestione dei casi di tap&scroll per caricare i dati in background
    var startDec = false
    var endDec = false
    var startDrag = false
    var endDrag = false
    
    let indexView = 1
    let cellIdentifier = "customcell"
    let detailSegueIdentifier = "ShowSegnalationDetailSegue"
    let locationManager = CLLocationManager()
    
    
    
    // MARK: - Funzioni
    override func viewDidLoad() {
        
        if (GlobalsMethods().getGPSAutorizationStatus()) {
            locationManager.delegate = self
            locationManager.desiredAccuracy = kCLLocationAccuracyBest
            locationValue = locationManager.location
            if (locationValue != nil) {
                segnalationArray = Segnalazione().getSegnalationsInRange(PFGeoPoint(latitude: locationValue.coordinate.latitude, longitude: locationValue.coordinate.longitude))
            }
        } else {
            segnalationArray = []
        }
        
        refreshControl.addTarget(self, action: "refresh:", forControlEvents: .ValueChanged)
        tableView.addSubview(refreshControl)
        tableView.delegate = self
        
        filterSegmentedControl.selectedSegmentIndex = 0
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        if (GlobalsMethods().getBoolOnNSUserDefaults(GlobalVariables.keyPreferencesForcedSync)){
            if (GlobalsMethods().isConnectedToNetwork()){
                if (GlobalsMethods().getGPSAutorizationStatus()) {
                    var waitAlert = SCLAlertView().showWait("Aggiornamento", subTitle: "Sto aggiornando i dati con le nuove impostazioni", duration: 0.0, closeButtonTitle: "", colorStyle: 0x00796B, colorTextButton: 0x4D4D4D)
                    dispatch_async(dispatch_get_global_queue(Int(QOS_CLASS_USER_INITIATED.value), 0)) {
                        var arraySegnalations = Segnalazione().updateWithOnline(PFGeoPoint(latitude: self.locationValue.coordinate.latitude, longitude: self.locationValue.coordinate.longitude))
                        var arrayUsers: [String] = []
                        for segnalation in arraySegnalations {
                            var user = segnalation[Segnalazione.user] as! PFObject
                            arrayUsers.append(user.objectId!)
                        }
                        let arrayUsersUnique = self.uniq(arrayUsers)
                        
                        Utente().updateWithOnline(arrayUsersUnique)
                        Valutazione().updateWithOnline(arraySegnalations)
                        self.changeFilter(self.filterSegmentedControl)
                        dispatch_async(dispatch_get_main_queue()) {
                            waitAlert.close()
                            GlobalsMethods().writeOnNSUserDefaults(GlobalVariables.keyPreferencesForcedSync, value: false)
                        }
                    }
                }
            } else {
                SCLAlertView().showError("Connessione assente", subTitle: "Controlla che il tuo dispositivo sia connesso a internet")
            }
        }else{
            self.changeFilter(self.filterSegmentedControl)
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
            var c: CustomCell = cell as! CustomCell
            if (dictObjectDownload.indexForKey(c.segnalation.objectId!) == nil) {
                var str = c.segnalation.objectId! as String
                dictObjectDownload[str] = cell.segnalation as PFObject
            }
        }
        //inizio download
        asyncDownload()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if (segue.identifier == detailSegueIdentifier) {
            if let destination = segue.destinationViewController as? DetailViewController {
                if let segnalationIndex = tableView.indexPathForSelectedRow()?.row {
                    var segnalation: PFObject = self.segnalationArray[segnalationIndex]
                    destination.segnalationObject = segnalation
                    destination.showSolve = segnalation[Segnalazione.solved] as! Bool
                }
            }
        }
    }
    
    // MARK: - @IBAction
    @IBAction func changeFilter(sender: UISegmentedControl) {
        switch filterSegmentedControl.selectedSegmentIndex {
        case 0:
            dispatch_async(dispatch_get_global_queue(Int(QOS_CLASS_USER_INITIATED.value), 0)) {
                //operazioni che esegue il thread
                if CLLocationManager.locationServicesEnabled() {
                    self.locationManager.desiredAccuracy = kCLLocationAccuracyBest
                    self.locationValue = self.locationManager.location
                    if (self.locationValue != nil) {
                        self.segnalationArray = Segnalazione().getSegnalationsInRange(PFGeoPoint(latitude: self.locationValue.coordinate.latitude, longitude: self.locationValue.coordinate.longitude))
                    }
                }
                dispatch_async(dispatch_get_main_queue()) {
                    self.tableView.reloadData()
                }
            }
            break
        case 1:
            dispatch_async(dispatch_get_global_queue(Int(QOS_CLASS_USER_INITIATED.value), 0)) {
                //operazioni che esegue il thread
                self.segnalationArray = Segnalazione().getSegnalationsOrderedByPriority()
                dispatch_async(dispatch_get_main_queue()) {
                    self.tableView.reloadData()
                }
            }
            break
        case 2:
            dispatch_async(dispatch_get_global_queue(Int(QOS_CLASS_USER_INITIATED.value), 0)) {
                //operazioni che esegue il thread
                self.segnalationArray = Segnalazione().getSegnalationsOrderedByDate()
                dispatch_async(dispatch_get_main_queue()) {
                    self.tableView.reloadData()
                }
            }
            break
        case 3:
            dispatch_async(dispatch_get_global_queue(Int(QOS_CLASS_USER_INITIATED.value), 0)) {
                //operazioni che esegue il thread
                self.segnalationArray = Segnalazione().getSegnalationsOrderedByPopularity()
                dispatch_async(dispatch_get_main_queue()) {
                    self.tableView.reloadData()
                }
            }
            break
        default:
            break
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
                    var c: CustomCell = cell as! CustomCell
                    if (dictObjectDownload.indexForKey(c.segnalation.objectId!) == nil) {
                        var str = c.segnalation.objectId! as String
                        dictObjectDownload[str] = cell.segnalation as PFObject
                    }
                }
            } else {
                //case 1
                var visibleCells = tableView.visibleCells()
                for cell in visibleCells {
                    var c: CustomCell = cell as! CustomCell
                    if (dictObjectDownload.indexForKey(c.segnalation.objectId!) == nil) {
                        var str = c.segnalation.objectId! as String
                        dictObjectDownload[str] = cell.segnalation as PFObject
                    }
                }
            }
            //inizio download
            asyncDownload()
            
        }
    }
    
    func scrollViewWillBeginDragging(scrollView: UIScrollView) {
        startDrag = true
        endDec = false
    }
    
    func scrollViewDidEndDragging(scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        startDrag = false
        endDrag = true
    }
    
    
    
    //MARK: - Riempimento TableView
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return segnalationArray.count
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        var cell: CustomCell = self.tableView.dequeueReusableCellWithIdentifier(cellIdentifier) as! CustomCell
        var segnalation: PFObject = self.segnalationArray[indexPath.row]
        cell.titleLabel.text = segnalation[Segnalazione.title] as? String
        cell.descriptionLabel.text = segnalation[Segnalazione.description] as? String
        
        //setto il campo objectId
        cell.segnalation = segnalation
        
        cell.distanceLabel.layer.cornerRadius = 20
        cell.distanceLabel.clipsToBounds = true
        
        
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
        
        var segnalationPosition: PFGeoPoint = segnalation[Segnalazione.position] as! PFGeoPoint
        if CLLocationManager.locationServicesEnabled() {
            locationManager.desiredAccuracy = kCLLocationAccuracyBest
            locationValue = locationManager.location
            if (locationValue != nil) {
                var myLocationGeoPoint: PFGeoPoint = PFGeoPoint(latitude: locationValue.coordinate.latitude, longitude: locationValue.coordinate.longitude)
                var distanceInKilometers: Double = myLocationGeoPoint.distanceInKilometersTo(segnalationPosition)
                if (distanceInKilometers >= 0 && distanceInKilometers < 1 ) {
                    cell.distanceLabel.text = String(format: "%.0f m", distanceInKilometers * 1000)
                } else {
                    cell.distanceLabel.text = String(format: "%.1f km", distanceInKilometers)
                }
            }
            
        }
        
        return cell
    }
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        tableView.deselectRowAtIndexPath(indexPath, animated: true)
    }
    
    
    //MARK: - Refresh della TableView tramite pull to refresh
    func refresh(refreshControl: UIRefreshControl) {
        //controllo connessione ad internet
        if (GlobalsMethods().isConnectedToNetwork()){
            if (GlobalsMethods().getGPSAutorizationStatus()) {
                //crea un thread async
                dispatch_async(dispatch_get_global_queue(Int(QOS_CLASS_USER_INITIATED.value), 0)) {
                    //operazioni che esegue il thread
                    self.syncWithParseOnline()
                    
                    self.changeFilter(self.filterSegmentedControl)
                    
                    self.locationManager.desiredAccuracy = kCLLocationAccuracyBest
                    self.locationValue = self.locationManager.location
                    
                    dispatch_async(dispatch_get_main_queue()) {
                        self.tableView.reloadData()
                        refreshControl.endRefreshing()
                    }
                }
            }
        } else {
            SCLAlertView().showError("Connessione assente", subTitle: "Controlla che il tuo dispositivo sia connesso a internet")
            refreshControl.endRefreshing()
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
    
    //MARK: - Funzione che sincronizza tutti i dati con online da bottone
    func syncWithParseOnline() {
        var arraySegnalations = Segnalazione().updateWithOnline(PFGeoPoint(latitude: locationValue.coordinate.latitude, longitude: locationValue.coordinate.longitude))
        var arrayUsers: [String] = []
        for segnalation in arraySegnalations {
            var user = segnalation[Segnalazione.user] as! PFObject
            arrayUsers.append(user.objectId!)
        }
        let arrayUsersUnique = uniq(arrayUsers)
        Valutazione().updateWithOnline(arraySegnalations)
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