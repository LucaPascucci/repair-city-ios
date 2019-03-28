//
//  ViewController.swift
//  Repair City
//
//  Created by InfinityCode on 23/07/15.
//  Copyright (c) 2015 InfinityCode. All rights reserved.
//

import UIKit
import MapKit
import Parse

class MapViewController: UIViewController, CLLocationManagerDelegate, MKMapViewDelegate, BWWalkthroughViewControllerDelegate  {
    
    //MARK: - @IBOutlet
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var mapSegmentControl: UISegmentedControl!
    
    //MARK: - Variabili
    var locationManager: CLLocationManager!
    var segnalationClicked: PFObject!
    var firstOpenMap = true;
    var lastSyncPosition: CLLocation!
    var currentLocation: CLLocation!
    var visibleSegnalation = Dictionary<String, PinSegnalazione>()
    var firstAlert : SCLAlertViewResponder!
    var finishFirstDownload = false
    var startFirstDownload = false
    
    var walkthrough : BWWalkthroughViewController!
    let indexView = 0
    let segueIdentifier = "SegnalationFromMap"
    let onlineSync = 1
    let localSync = 2
    
    //MARK:
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if (GlobalsMethods().getBoolOnNSUserDefaults(GlobalVariables.ketPreferencesFirstLaunch)){
            showWalkthrough()
        }
        //Non dovrebbe servire visto che si trova nella schermata di benvenuto
        locationManager = CLLocationManager()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
        
        mapSegmentControl.layer.cornerRadius = 5
        
        mapView.delegate = self
        var mapType = GlobalsMethods().getMapOnNSUserDefaults(GlobalVariables.keyPreferencesMap)
        if (mapType != nil) {
            switch (mapType!) {
            case MKMapType.Standard.rawValue:
                mapView.mapType = MKMapType.Standard
                mapSegmentControl.selectedSegmentIndex = 0
                break
            case MKMapType.Hybrid.rawValue:
                mapView.mapType = MKMapType.Hybrid
                mapSegmentControl.selectedSegmentIndex = 1
                break
            case MKMapType.Satellite.rawValue:
                mapView.mapType = MKMapType.Satellite
                mapSegmentControl.selectedSegmentIndex = 2
                break
            default:
                break
            }
        }
        
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        if (!GlobalsMethods().getBoolOnNSUserDefaults(GlobalVariables.ketPreferencesFirstLaunch)){
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
            
            if (!firstOpenMap && !GlobalsMethods().getBoolOnNSUserDefaults(GlobalVariables.keyPreferencesForcedSync)){
                createMapAnnotation(localSync)
            }
            if (GlobalsMethods().getBoolOnNSUserDefaults(GlobalVariables.keyPreferencesForcedSync)){
                if(GlobalsMethods().isConnectedToNetwork()){
                    if (GlobalsMethods().getGPSAutorizationStatus()) {
                        var waitAlert = SCLAlertView().showWait("Aggiornamento", subTitle: "Sto aggiornando i dati con le nuove impostazioni", duration: 0.0, closeButtonTitle: "", colorStyle: 0x00796B, colorTextButton: 0x4D4D4D)
                        dispatch_async(dispatch_get_global_queue(Int(QOS_CLASS_USER_INITIATED.value), 0)) {
                            self.syncAllWithOnline()
                            //Faccio aggiornare la grafica della mappa
                            self.createMapAnnotation(self.localSync)
                            dispatch_async(dispatch_get_main_queue()) {
                                GlobalsMethods().writeOnNSUserDefaults(GlobalVariables.keyPreferencesForcedSync, value: false)
                                waitAlert.close()
                                
                            }
                        }
                    }
                } else {
                    SCLAlertView().showError("Connessione Assente", subTitle: "Controlla che il tuo dispositivo sia connesso a internet")
                }
            }
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if (segue.identifier == segueIdentifier) {
            if let destination = segue.destinationViewController as? DetailViewController {
                destination.segnalationObject = segnalationClicked
                destination.showSolve = segnalationClicked[Segnalazione.solved] as! Bool
            }
        }
    }
    
    //MARK: - @IBAction
    @IBAction func changeMapType(sender: UISegmentedControl) {
        switch mapSegmentControl.selectedSegmentIndex {
        case 0:
            mapView.mapType = MKMapType.Standard
            GlobalsMethods().writeOnNSUserDefaults(GlobalVariables.keyPreferencesMap, value: MKMapType.Standard.rawValue)
            break
        case 1:
            mapView.mapType = MKMapType.Hybrid
            GlobalsMethods().writeOnNSUserDefaults(GlobalVariables.keyPreferencesMap, value: MKMapType.Hybrid.rawValue)
            break
        case 2:
            mapView.mapType = MKMapType.Satellite
            GlobalsMethods().writeOnNSUserDefaults(GlobalVariables.keyPreferencesMap, value: MKMapType.Satellite.rawValue)
            break
        default:
            break
        }
    }
    
    @IBAction func zoomInPosition(sender: AnyObject) {
        //controllo se ci sono i permessi per visualizzare la posizione dell'utente
        if (GlobalsMethods().getGPSAutorizationStatus()){
            if (currentLocation != nil){
                //zoom verso la posizione dell'utente
                let region = MKCoordinateRegionMakeWithDistance(currentLocation.coordinate, 2000, 2000)
                mapView.setRegion(region, animated: true)
            }
        }
    }
    
    @IBAction func refreshOnline(sender: AnyObject) {
        if(GlobalsMethods().isConnectedToNetwork()){
            if GlobalsMethods().getGPSAutorizationStatus(){
                lastSyncPosition = locationManager.location
                createMapAnnotation(onlineSync)
            }
        }else{
            SCLAlertView().showError("Connessione Assente", subTitle: "Controlla che il tuo dispositivo sia connesso ad internet")
        }
    }
    
    //MARK: - Definizione metodi per gestione aggiunta dei pin e creazione callout personalizzati
    func mapView(mapView: MKMapView!, viewForAnnotation annotation: MKAnnotation!) -> MKAnnotationView!{
        
        if let annotationPin = annotation as? PinSegnalazione {
            var annotationView = MKAnnotationView(annotation: annotationPin, reuseIdentifier: annotationPin.UUID)
            annotationView.canShowCallout = true
            
            var imageView = UIImageView(frame: CGRect(x: 10, y: 0, width: 45, height: 45))
            imageView.contentMode = UIViewContentMode.ScaleAspectFit
            imageView.image = annotationPin.preview
            imageView.layer.cornerRadius = 10
            imageView.clipsToBounds = true
            
            annotationView.leftCalloutAccessoryView = imageView
            annotationView.rightCalloutAccessoryView = UIButton.buttonWithType(.DetailDisclosure) as! UIView
            
            var endFrame: CGRect = annotationView.frame
            annotationView.frame = CGRectOffset(endFrame, 0, -500)
            UIView.animateWithDuration(0.5, animations: {
                annotationView.frame = endFrame
            })
            
            switch (annotationPin.priority) {
            case 1:
                annotationView.image = UIImage(named: "LowPin.png")
                break
            case 2:
                annotationView.image = UIImage(named: "MediumPin.png")
                break
            case 3:
                annotationView.image = UIImage(named: "HighPin.png")
                break
            default:
                break
            }
            annotationView.centerOffset = CGPointMake(5.0, -15.0)
            annotationView.calloutOffset = CGPointMake(-8.0,0.0)
            return annotationView
        }
        return nil
    }
    
    func mapView(mapView: MKMapView!, annotationView view: MKAnnotationView!, calloutAccessoryControlTapped control: UIControl!) {
        let clickedPin = view.annotation as! PinSegnalazione
        segnalationClicked = clickedPin.segnalation
        self.performSegueWithIdentifier(segueIdentifier, sender: self)
    }
    
    //MARK: - Rimosso callout current location e precarico dell'utente e valutazioni in base al pin premuto
    func mapView(mapView: MKMapView!, didSelectAnnotationView view: MKAnnotationView!) {
        if (view.annotation.isKindOfClass(MKUserLocation)){
            mapView.deselectAnnotation(view.annotation, animated: false)
        }
        
        if (view.annotation.isKindOfClass(PinSegnalazione)){
            var pinAnnotation = view.annotation as! PinSegnalazione
            preloadUserAndValutations(pinAnnotation.segnalation)
        }
    }
    
    //MARK: - Funzione che continuamente controlla la posizione dell'utente
    func locationManager(manager: CLLocationManager!, didUpdateLocations locations: [AnyObject]!) {
        currentLocation = manager.location
        if (!GlobalsMethods().getBoolOnNSUserDefaults(GlobalVariables.ketPreferencesFirstLaunch)){
            if (firstOpenMap){
                firstOpenMap = !firstOpenMap
                let region = MKCoordinateRegionMakeWithDistance(currentLocation.coordinate, 2000, 2000)
                mapView.setRegion(region, animated: true)
                lastSyncPosition = currentLocation
                createMapAnnotation(localSync)
            }
            
            var distance = lastSyncPosition.distanceFromLocation(currentLocation)
            //aggiorna solo se l'utente si sposta di più di due km dalla ultima posizione di sincronizzazione online
            if (distance > 2000){
                createMapAnnotation(onlineSync)
                lastSyncPosition = currentLocation
            }
        }else{
            if (!startFirstDownload){
                startFirstDownload = !startFirstDownload
                dispatch_async(dispatch_get_global_queue(Int(QOS_CLASS_USER_INITIATED.value), 0)) {
                    self.syncAllWithOnline()
                    let region = MKCoordinateRegionMakeWithDistance(self.currentLocation.coordinate, 2000, 2000)
                    self.mapView.setRegion(region, animated: true)
                    self.createMapAnnotation(self.localSync)
                    dispatch_async(dispatch_get_main_queue()) {
                    }
                }
            }
        }
    }
    
    //MARK: - Precarica gli utenti e le segnalazioni se non presenti in locale
    func preloadUserAndValutations(segnalation : PFObject){
        if (GlobalsMethods().isConnectedToNetwork()) {
            dispatch_async(dispatch_get_global_queue(Int(QOS_CLASS_USER_INITIATED.value), 0)) {
                var segnalationUser = segnalation[Segnalazione.user] as! PFObject
                //cerco se l'utente è gia presente
                if (Utente().getUserFromObjectID(segnalationUser.objectId as String!) == nil){
                    var userID : [String] = [segnalationUser.objectId as String!]
                    var utenti = Utente().updateWithOnline(userID)
                    //sarà sempre un for da un utente
                    for utente in utenti {
                        var profilePhotoFIle = utente[Utente.profilePhoto] as! PFFile
                        profilePhotoFIle.getData()
                    }
                }
                //scarico le segnalazioni online
                var segnalationArray = [segnalation]
                Valutazione().updateWithOnline(segnalationArray)
                dispatch_async(dispatch_get_main_queue()) {
                }
            }
        } else {
            SCLAlertView().showError("Connessione assente", subTitle: "Controlla che il tuo dispositivo sia connesso a internet")
        }
    }
    
    //MARK: - Crea i pin
    func createMapAnnotation(source : Int){
        if (currentLocation != nil){
            dispatch_async(dispatch_get_global_queue(Int(QOS_CLASS_USER_INITIATED.value), 0)) {
                var segnalations = [PFObject]()
                if (source == self.localSync){
                    segnalations = Segnalazione().getSegnalationsInRange(PFGeoPoint(location: self.currentLocation)) as [PFObject]
                }else{
                    if (GlobalsMethods().isConnectedToNetwork()) {
                        segnalations = Segnalazione().updateWithOnline(PFGeoPoint(location: self.currentLocation)) as [PFObject]
                    } else {
                        SCLAlertView().showError("Connessione assente", subTitle: "Controlla che il tuo dispositivo sia connesso a internet")
                    }
                }
                var newSegnalations = Dictionary<String, PinSegnalazione>()
                if (!segnalations.isEmpty) {
                    for curr in segnalations {
                        var position = curr[Segnalazione.position] as! PFGeoPoint
                        var segnalationImageFile = curr[Segnalazione.segnalationPhoto] as! PFFile
                        var segnalationImageData = segnalationImageFile.getData()
                        var identifier = curr.objectId as String!
                        var image = UIImage(data: segnalationImageData!)
                        let pinSegnalation = PinSegnalazione(title: curr[Segnalazione.title] as! String, description: curr[Segnalazione.description] as! String, coordinate: CLLocationCoordinate2D(latitude: position.latitude, longitude: position.longitude), segnalationObject: curr, identifier: identifier, preview: image!, priority: curr[Segnalazione.priority] as! Int)
                        
                        newSegnalations[identifier] = pinSegnalation
                    }
                }
                dispatch_async(dispatch_get_main_queue()) {
                    //Rimuovo tutte le segnalazioni non presenti nel raggio impostato
                    for visibleKey in self.visibleSegnalation.keys{
                        if (newSegnalations.indexForKey(visibleKey) == nil){
                            var annotation = self.visibleSegnalation.removeValueForKey(visibleKey)
                            self.mapView.removeAnnotation(annotation)
                        }
                    }
                    //Aggiungo tutte le nuove segnalazioni
                    for newKey in newSegnalations.keys {
                        if (self.visibleSegnalation.indexForKey(newKey) == nil){
                            self.visibleSegnalation[newKey] = newSegnalations[newKey]
                            self.mapView.addAnnotation(self.visibleSegnalation[newKey])
                        }
                    }
                    
                    //Utilizzata solo al primissimo avvio
                    self.finishFirstDownload = true
                    if (self.firstAlert != nil){
                        self.firstAlert.close()
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
        if (currentLocation != nil){
            var arraySegnalations = Segnalazione().updateWithOnline(PFGeoPoint(location: currentLocation))
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
    
    func showWalkthrough(){
        
        GlobalsMethods().writeOnNSUserDefaults(GlobalVariables.keyPreferencesSegnalationRange, value: 25)
        
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
        GlobalsMethods().writeOnNSUserDefaults(GlobalVariables.ketPreferencesFirstLaunch, value: false)
        if (!finishFirstDownload){
            
            firstAlert = SCLAlertView().showWait("Caricamento", subTitle: "Sto preparando l'applicazione per il primo utilizzo", duration: 0.0, closeButtonTitle: "", colorStyle: 0x00796B, colorTextButton: 0x4D4D4D)
        }
    }
    
}