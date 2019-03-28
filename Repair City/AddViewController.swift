//
//  AddViewController.swift
//  Repair City
//
//  Created by InfinityCode on 27/07/15.
//  Copyright (c) 2015 InfinityCode. All rights reserved.
//

import Foundation
import UIKit
import MapKit
import Parse
import Bolts
import SimpleAlert

class AddViewController: UIViewController, CLLocationManagerDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UITextViewDelegate, UITextFieldDelegate, MKMapViewDelegate {
    
    //MARK: - @IBOutlet
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var segnalationTitle: UITextField!
    @IBOutlet weak var segnalationDescription: UITextView!
    @IBOutlet weak var priorityLabel: UILabel!
    @IBOutlet weak var priorityControl: UISegmentedControl!
    @IBOutlet weak var userImage: UIImageView!
    @IBOutlet weak var userName: UILabel!
    @IBOutlet weak var segnalationImage: UIImageView!
    
    //MARK: - Variabili
    var locationManager: CLLocationManager!
    var valuePreferences: UInt!
    var insertPhoto = false
    var priority: Int = 1
    var currUser : PFObject!
    var insertPhotoData = NSData()
    var currentLocation: CLLocation!
    
    //MARK:
    override func viewDidLoad() {
        super.viewDidLoad()
        
        segnalationTitle.delegate = self
        
        //Abilitare singolo tap sull'immagine da aggiungere
        let tapImage = UITapGestureRecognizer()
        tapImage.addTarget(self, action: "chooseSource")
        segnalationImage.addGestureRecognizer(tapImage)
        segnalationImage.userInteractionEnabled = true
        
        segnalationDescription.text = "Descrizione"
        segnalationDescription.textColor = GlobalsMethods().UIColorFromRGB(0xC7C7CD)
        segnalationDescription!.delegate = self
        
        priorityControl.tintColor = GlobalsMethods().UIColorFromRGB(0xFFC107)
        priorityControl.layer.cornerRadius = 5
        
        //round corners for the userImage
        userImage.layer.cornerRadius = 20.0
        userImage.clipsToBounds = true
        
        segnalationImage.autoresizingMask = UIViewAutoresizing.FlexibleBottomMargin | UIViewAutoresizing.FlexibleHeight | UIViewAutoresizing.FlexibleRightMargin | UIViewAutoresizing.FlexibleLeftMargin | UIViewAutoresizing.FlexibleTopMargin | UIViewAutoresizing.FlexibleWidth
        segnalationImage.contentMode = UIViewContentMode.ScaleAspectFit
        
        //Avviare il locationManager che controlla la posizione dell'utente
        locationManager = CLLocationManager()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.startUpdatingLocation()
        
        mapView.delegate = self
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        var mapType = GlobalsMethods().getMapOnNSUserDefaults(GlobalVariables.keyPreferencesMap)
        if (mapType != nil) {
            switch (mapType!) {
            case MKMapType.Standard.rawValue:
                mapView.mapType = MKMapType.Standard
            case MKMapType.Hybrid.rawValue:
                mapView.mapType = MKMapType.Hybrid
            case MKMapType.Satellite.rawValue:
                mapView.mapType = MKMapType.Satellite
            default:
                mapView.mapType = MKMapType.Standard
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
        
        dispatch_async(dispatch_get_global_queue(Int(QOS_CLASS_USER_INITIATED.value), 0)) {
            //operazioni che esegue il thread
            self.currUser = Utente().getLocalUserObject(GlobalsMethods().getUserOnNSUserDefaults(GlobalVariables.keyPreferencesFB)!)!
            var profilePhoto = Utente().getUserProfilePhoto(self.currUser)
            dispatch_async(dispatch_get_main_queue()) {
                if (self.currUser != nil) {
                    self.userName.text = (self.currUser[Utente.name] as! String)
                    if (profilePhoto != nil){
                        self.userImage.image = profilePhoto
                    }
                }
            }
        }
        
        if (tabBarIsVisible()){
            setTabBarVisible(!tabBarIsVisible(), animated: true)
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    //MARK: - @IBAction
    @IBAction func returnToPreviousView(sender: AnyObject) {
        backToPrevious()
    }
    
    @IBAction func priorityChanged(sender: AnyObject) {
        switch priorityControl.selectedSegmentIndex {
        case 0:
            priorityControl.tintColor = GlobalsMethods().UIColorFromRGB(0xFFC107)
            priority = 1
            break
        case 1:
            priorityControl.tintColor = UIColor.orangeColor()
            priority = 2
            break
        case 2:
            priorityControl.tintColor = UIColor.redColor()
            priority = 3
            break
        default:
            break
        }
    }
    
    @IBAction func confirmNewSegnalation(sender: AnyObject) {
        
        if (GlobalsMethods().getGPSAutorizationStatus()){
            var txtTitle = segnalationTitle.text
            var txtDescription = segnalationDescription.text
            var name = userName.text
            
            //check befor submission
            if (GlobalsMethods().isConnectedToNetwork()){
                
                if (!txtTitle.isEmpty && !(segnalationDescription.textColor == GlobalsMethods().UIColorFromRGB(0xC7C7CD)) && insertPhoto) {
                    
                    var waitAlert = SCLAlertView().showWait("Caricamento", subTitle: "Sto caricando la tua segnalazione", duration: 0.0, closeButtonTitle: "", colorStyle: 0x00796B, colorTextButton: 0x4D4D4D)
                    
                    //crea un thread async
                    dispatch_async(dispatch_get_global_queue(Int(QOS_CLASS_USER_INITIATED.value), 0)) {
                        //operazioni che esegue il thread
                        let checkInserimento = Segnalazione().insert(txtTitle, description: txtDescription, priority: self.priority, latitude: self.currentLocation.coordinate.latitude, longitude: self.currentLocation.coordinate.longitude, segnalationPhoto: self.insertPhotoData, user: self.currUser)
                        dispatch_async(dispatch_get_main_queue()) {
                            //operazioni che esegue il thread una volta finite le prime operazioni
                            waitAlert.close()
                            if (checkInserimento){
                                SCLAlertView().showCustomSuccess("Inserimento", subTitle: "Segnalazione caricata con successo", colorStyle: 0x00796B, colorTextButton: 0xFFFFFF)
                            }else{
                                SCLAlertView().showInfo("Salvata in locale", subTitle: "La segnalazione verrà caricata online il prima possibile")
                            }
                            self.resetFields()
                            self.backToPrevious()
                        }
                    }
                    
                } else {
                    SCLAlertView().showWarning("Attenzione", subTitle: "I campi non sono stati compilati in modo corretto")
                }
            }else{
                SCLAlertView().showError("Connessione Assente", subTitle: "Controlla che il tuo dispositivo sia connesso ad internet")
            }
        }
    }
    
    //MARK: - Funzione che continuamente controlla la posizione dell'utente
    func locationManager(manager: CLLocationManager!, didUpdateLocations locations: [AnyObject]!) {
        currentLocation = manager.location
        if (currentLocation != nil){
            //zoom verso la posizione dell'utente
            let region = MKCoordinateRegionMakeWithDistance(currentLocation.coordinate, 150, 150)
            mapView.setRegion(region, animated: true)
        }
    }
    
    //MARK: - Metodi per Immagine
    func chooseSource() {
        
        let alertController = CustomSimpleAlert(title: nil, message: "Aggiungi una foto \n\n Scegli come aggiungere la foto della segnalazione", style: SimpleAlert.Controller.Style.ActionSheet)
        
        alertController.addAction(SimpleAlert.Action(title: "Annulla", style: .Cancel))
        alertController.addAction(SimpleAlert.Action(title: "Scatta una foto", style: .OK){
            action in
            
            if (UIImagePickerController.isSourceTypeAvailable(.Camera)){
                //apre la fotocamera se è stata autorizzata dall'utente
                let picker = UIImagePickerController()
                picker.sourceType = UIImagePickerControllerSourceType.Camera
                picker.delegate = self
                picker.allowsEditing = false
                if (GlobalsMethods().getCameraStatus()){
                    self.presentViewController(picker, animated: true, completion: nil)
                }
            }else{
                //Fotocamera non disponibile
                SCLAlertView().showError("Errore", subTitle: "La fotocamera non è disponibile")
            }
            
            })
        alertController.addAction(SimpleAlert.Action(title: "Scegli una foto esistente", style: .OK){
            action in
            
            let picker = UIImagePickerController()
            picker.sourceType = UIImagePickerControllerSourceType.PhotoLibrary
            picker.mediaTypes = UIImagePickerController.availableMediaTypesForSourceType(.PhotoLibrary)!
            picker.delegate = self
            picker.allowsEditing = false
            if (GlobalsMethods().getPhotoLibraryStatus()){
                self.presentViewController(picker, animated: true, completion: nil)
            }
            
            })
        
        presentViewController(alertController, animated: true, completion: nil)
    }
    
    func imagePickerController(picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [NSObject : AnyObject]){
        let image: UIImage = info[UIImagePickerControllerOriginalImage] as! UIImage
        insertPhoto = true
        insertPhotoData = UIImageJPEGRepresentation(image, 0.15)
        segnalationImage.image = image
        picker.dismissViewControllerAnimated(true, completion: nil)
        
    }
    
    func imagePickerControllerDidCancel(picker: UIImagePickerController){
        picker.dismissViewControllerAnimated(true, completion: nil)
    }
    
    //MARK: - Placeholder TextView
    func textViewDidBeginEditing(textView: UITextView) {
        if (segnalationDescription.textColor == GlobalsMethods().UIColorFromRGB(0xC7C7CD)) {
            segnalationDescription.text = nil
            segnalationDescription.textColor = UIColor.blackColor()
        }
    }
    
    func textViewDidEndEditing(textView: UITextView) {
        if (segnalationDescription.text.isEmpty) {
            segnalationDescription.text = "Descrizione"
            segnalationDescription.textColor = GlobalsMethods().UIColorFromRGB(0xC7C7CD)
        }
    }
    
    //MARK: - Nascondere Tab Bar
    func setTabBarVisible(visible:Bool, animated:Bool) {
        
        //controllo se la tabBar si trova già nel giusto stato
        if (tabBarIsVisible() == visible) { return }
        
        // ottiene il frame e calcola l'offset per il movimento
        let frame = self.tabBarController?.tabBar.frame
        let height = frame?.size.height
        let offsetY = (visible ? -height! : height)
        
        //durata dell'animazione
        let duration:NSTimeInterval = (animated ? 0.3 : 0.0)
        
        //anima la tab bar
        if frame != nil {
            UIView.animateWithDuration(duration) {
                self.tabBarController?.tabBar.frame = CGRectOffset(frame!, 0, offsetY!)
                return
            }
        }
    }
    
    func tabBarIsVisible() ->Bool {
        return self.tabBarController?.tabBar.frame.origin.y < CGRectGetMaxY(self.view.frame)
    }
    
    //MARK: - Limitare inserimento Titolo
    func textField(textField: UITextField, shouldChangeCharactersInRange range: NSRange, replacementString string: String) -> Bool {
        let newLength = count(textField.text.utf16) + count(string.utf16) - range.length
        return newLength <= 20
    }
    
    //MARK: - Rimosso callout current location
    func mapView(mapView: MKMapView!, didSelectAnnotationView view: MKAnnotationView!) {
        if (view.annotation.isKindOfClass(MKUserLocation)){
            mapView.deselectAnnotation(view.annotation, animated: false)
        }
    }
    
    //MARK: - Torna alla view precedente
    func backToPrevious (){
        if (!tabBarIsVisible()){
            setTabBarVisible(!tabBarIsVisible(), animated: true)
        }
        var previousView = GlobalsMethods().getPreviousViewOnNSUserDefaults(GlobalVariables.keyPreferencesPreviousView)
        tabBarController?.selectedIndex = previousView!
    }
    
    //MARK: - Reset dei campi
    func resetFields(){
        segnalationTitle.text = ""
        segnalationDescription.text = "Descrizione"
        segnalationDescription.textColor = GlobalsMethods().UIColorFromRGB(0xC7C7CD)
        
        priorityControl.tintColor = GlobalsMethods().UIColorFromRGB(0xFFC107)
        priorityControl.selectedSegmentIndex = 0
        priority = 1
        
        segnalationImage.image = UIImage(named: "AddImage.png")
        insertPhoto = false
    }
}