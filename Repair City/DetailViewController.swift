//
//  DetailViewController.swift
//  Repair City
//
//  Created by InfinityCode on 30/07/15.
//  Copyright (c) 2015 InfinityCode. All rights reserved.
//

import Foundation
import UIKit
import MapKit
import Parse
import FBSDKCoreKit
import FBSDKLoginKit
import Social
import SimpleAlert

class DetailViewController: UIViewController, MKMapViewDelegate, UINavigationControllerDelegate, UIActionSheetDelegate {
    
    //MARK: - @IBOutlet
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var segnalationDescription: UITextView!
    @IBOutlet weak var likeImage: UIImageView!
    @IBOutlet weak var likeLabel: UILabel!
    @IBOutlet weak var notLikeImage: UIImageView!
    @IBOutlet weak var notLikeLabel: UILabel!
    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var userImage: UIImageView!
    @IBOutlet weak var userName: UILabel!
    @IBOutlet weak var segnalationPhoto: UIImageView!
    
    //MARK: - Variabili
    var user: PFObject!
    var segnalationObject: PFObject!
    var showSolve: Bool!
    
    //MARK: - caricamento view
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.automaticallyAdjustsScrollViewInsets = false
        
        user = segnalationObject[Segnalazione.user] as! PFObject
        
        userImage.layer.cornerRadius = 20.0
        userImage.clipsToBounds = true
        
        segnalationPhoto.autoresizingMask = UIViewAutoresizing.FlexibleBottomMargin | UIViewAutoresizing.FlexibleHeight | UIViewAutoresizing.FlexibleRightMargin | UIViewAutoresizing.FlexibleLeftMargin | UIViewAutoresizing.FlexibleTopMargin | UIViewAutoresizing.FlexibleWidth
        segnalationPhoto.contentMode = UIViewContentMode.ScaleAspectFit
        
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
        
        self.title = segnalationObject[Segnalazione.title] as? String
        
        var dateFormatter = NSDateFormatter()
        dateFormatter.dateFormat = "dd/MM/yyyy"
        dateLabel.text = "Data ultima modifica: \(dateFormatter.stringFromDate(segnalationObject.updatedAt!))"
        
        var position = segnalationObject[Segnalazione.position] as! PFGeoPoint
        var segnalationAnnotation = PinSegnalazione(title: segnalationObject[Segnalazione.title] as! String, description: segnalationObject[Segnalazione.description] as! String, coordinate: CLLocationCoordinate2D(latitude: position.latitude, longitude: position.longitude), segnalationObject: segnalationObject, identifier: "", preview: UIImage(), priority: segnalationObject[Segnalazione.priority] as! Int)
        
        let region = MKCoordinateRegionMakeWithDistance(segnalationAnnotation.coordinate, 300, 300)
        mapView.setRegion(region, animated: true)
        mapView.addAnnotation(segnalationAnnotation)
        
        segnalationDescription.text = segnalationObject[Segnalazione.description] as! String
        
        //Abilitare singolo tap su like
        let tapLike = UITapGestureRecognizer()
        tapLike.addTarget(self, action: "tapLike")
        likeImage.addGestureRecognizer(tapLike)
        likeImage.userInteractionEnabled = true
        
        //Abilitare singolo tap su like
        let tapNotLike = UITapGestureRecognizer()
        tapNotLike.addTarget(self, action: "tapNotLike")
        notLikeImage.addGestureRecognizer(tapNotLike)
        notLikeImage.userInteractionEnabled = true
        
        dispatch_async(dispatch_get_global_queue(Int(QOS_CLASS_USER_INITIATED.value), 0)) {
            //operazioni che esegue il thread
            //carico like e notLike
            var like = Valutazione().getNumberOfLikesOrDislikes(self.segnalationObject, likeOrNotLike: 1)
            var notLike = Valutazione().getNumberOfLikesOrDislikes(self.segnalationObject, likeOrNotLike: -1)
            
            //controllo se l'utente ha già una valutazione
            var currUser = Utente().getLocalUserObject(GlobalsMethods().getUserOnNSUserDefaults(GlobalVariables.keyPreferencesFB)!)!
            var valutation = Valutazione().getValutationType(currUser, segnalation: self.segnalationObject)
            
            //carico l'immagine dell'utente
            var linkedUser = Utente().getUserFromObjectID(self.user.objectId!)
            let userImageFile = self.user[Utente.profilePhoto] as! PFFile
            var userImageData = userImageFile.getData()
            
            //prendo l'immagine della segnalazione
            let segnalationImageFile = self.segnalationObject[Segnalazione.segnalationPhoto] as! PFFile
            var segnalationImageData = segnalationImageFile.getData()
            dispatch_async(dispatch_get_main_queue()) {
                
                //setto il pollice pieno se l'utente ha già messo una valutazione
                if (valutation == 1) {
                    self.likeImage.image = UIImage(named: "ThumbUpFilled")
                } else if (valutation == -1) {
                    self.notLikeImage.image = UIImage(named: "ThumbDownFilled")
                }
                
                //setto like e notLike
                self.likeLabel.text = "\(like)"
                self.notLikeLabel.text = "\(notLike)"
                
                //setto l'immagine dell'utente
                self.userImage.image = UIImage(data: userImageData!)
                self.userName.text = self.user[Utente.name] as? String
                
                //setto l'immagine della segnalazione
                self.segnalationPhoto.image = UIImage(data: segnalationImageData!)
            }
        }
    }
    
    //MARK: - @IBAction
    @IBAction func shareButtonItem(sender: AnyObject) {
        
        let alertController = CustomSimpleAlert(title: nil, message: nil, style: SimpleAlert.Controller.Style.ActionSheet)
        
        alertController.addAction(SimpleAlert.Action(title: "Annulla", style: .Cancel))
        if (self.showSolve == false) {
            alertController.addAction(SimpleAlert.Action(title: "Risolvi", style: .Default){
                action in
                self.solveSegnalation()
                })
        }
        alertController.addAction(SimpleAlert.Action(title: "Facebook", style: .OK){
            action in
            self.shareFacebook()
            })
        alertController.addAction(SimpleAlert.Action(title: "Twitter", style: .OK){
            action in
            self.shareTwitter()
            })
        
        presentViewController(alertController, animated: true, completion: nil)
    }
    
    //MARK: - Definizione metodi per gestione aggiunta del pin
    func mapView(mapView: MKMapView!, viewForAnnotation annotation: MKAnnotation!) -> MKAnnotationView!{
        if let annotationPin = annotation as? PinSegnalazione {
            
            var annotationView = MKAnnotationView(annotation: annotationPin, reuseIdentifier: "pinDettaglio")
            annotationView.canShowCallout = true
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
    
    //MARK: - Funzioni per Like/Not Like
    func tapLike() {
        if (GlobalsMethods().isConnectedToNetwork()) {
            dispatch_async(dispatch_get_global_queue(Int(QOS_CLASS_USER_INITIATED.value), 0)) {
                var currUser = Utente().getLocalUserObject(GlobalsMethods().getUserOnNSUserDefaults(GlobalVariables.keyPreferencesFB)!)!
                
                var checkExist = Valutazione().checkValutationExistOnline(currUser, segnalation: self.segnalationObject!)
                
                var valutationType = Valutazione().getValutationType(currUser, segnalation: self.segnalationObject)
                
                var like: Int!
                var notLike: Int!
                
                dispatch_async(dispatch_get_main_queue()) {
                    if (checkExist) {
                        if (valutationType == 1) {
                            //il record esiste già, era like: lo annullo
                            dispatch_async(dispatch_get_global_queue(Int(QOS_CLASS_USER_INITIATED.value), 0)) {
                                Valutazione().updateValutation(currUser, segnalation: self.segnalationObject, likeOrDislike: 0)
                                like = Valutazione().getNumberOfLikesOrDislikes(self.segnalationObject, likeOrNotLike: 1)
                                notLike = Valutazione().getNumberOfLikesOrDislikes(self.segnalationObject, likeOrNotLike: -1)
                                dispatch_async(dispatch_get_main_queue()) {
                                    self.likeImage.image = UIImage(named: "ThumbsUp")
                                    
                                    self.likeLabel.text = "\(like)"
                                    self.notLikeLabel.text = "\(notLike)"
                                }
                            }
                        } else if (valutationType == 0) {
                            //il record esiste già, era nullo
                            dispatch_async(dispatch_get_global_queue(Int(QOS_CLASS_USER_INITIATED.value), 0)) {
                                Valutazione().updateValutation(currUser, segnalation: self.segnalationObject, likeOrDislike: 1)
                                like = Valutazione().getNumberOfLikesOrDislikes(self.segnalationObject, likeOrNotLike: 1)
                                notLike = Valutazione().getNumberOfLikesOrDislikes(self.segnalationObject, likeOrNotLike: -1)
                                dispatch_async(dispatch_get_main_queue()) {
                                    self.likeImage.image = UIImage(named: "ThumbUpFilled")
                                    
                                    self.likeLabel.text = "\(like)"
                                    self.notLikeLabel.text = "\(notLike)"
                                }
                            }
                        } else {
                            //il record esiste già, era notLike: lo modifico
                            dispatch_async(dispatch_get_global_queue(Int(QOS_CLASS_USER_INITIATED.value), 0)) {
                                Valutazione().updateValutation(currUser, segnalation: self.segnalationObject, likeOrDislike: 1)
                                like = Valutazione().getNumberOfLikesOrDislikes(self.segnalationObject, likeOrNotLike: 1)
                                notLike = Valutazione().getNumberOfLikesOrDislikes(self.segnalationObject, likeOrNotLike: -1)
                                dispatch_async(dispatch_get_main_queue()) {
                                    self.likeImage.image = UIImage(named: "ThumbUpFilled")
                                    self.notLikeImage.image = UIImage(named: "ThumbsDown")
                                    
                                    self.likeLabel.text = "\(like)"
                                    self.notLikeLabel.text = "\(notLike)"
                                }
                            }
                        }
                    } else {
                        //la valutazione non esiste e la inserisco
                        dispatch_async(dispatch_get_global_queue(Int(QOS_CLASS_USER_INITIATED.value), 0)) {
                            Valutazione().insert(1, user: currUser, segnalation: self.segnalationObject)
                            like = Valutazione().getNumberOfLikesOrDislikes(self.segnalationObject, likeOrNotLike: 1)
                            notLike = Valutazione().getNumberOfLikesOrDislikes(self.segnalationObject, likeOrNotLike: -1)
                            dispatch_async(dispatch_get_main_queue()) {
                                self.likeImage.image = UIImage(named: "ThumbUpFilled")
                                
                                self.likeLabel.text = "\(like)"
                                self.notLikeLabel.text = "\(notLike)"
                            }
                        }
                    }
                }
            }
        } else {
            SCLAlertView().showError("Connessione Assente", subTitle: "Controlla che il tuo dispositivo sia connesso ad internet")
        }
    }
    
    func tapNotLike() {
        if (GlobalsMethods().isConnectedToNetwork()) {
            dispatch_async(dispatch_get_global_queue(Int(QOS_CLASS_USER_INITIATED.value), 0)) {
                
                var currUser = Utente().getLocalUserObject(GlobalsMethods().getUserOnNSUserDefaults(GlobalVariables.keyPreferencesFB)!)!
                
                var checkExist = Valutazione().checkValutationExistOnline(currUser, segnalation: self.segnalationObject!)
                
                var valutationType = Valutazione().getValutationType(currUser, segnalation: self.segnalationObject)
                
                var like: Int!
                var notLike: Int!
                
                dispatch_async(dispatch_get_main_queue()) {
                    if (checkExist) {
                        if (valutationType == -1) {
                            //il record esiste già, era notLike: lo annullo
                            dispatch_async(dispatch_get_global_queue(Int(QOS_CLASS_USER_INITIATED.value), 0)) {
                                Valutazione().updateValutation(currUser, segnalation: self.segnalationObject, likeOrDislike: 0)
                                like = Valutazione().getNumberOfLikesOrDislikes(self.segnalationObject, likeOrNotLike: 1)
                                notLike = Valutazione().getNumberOfLikesOrDislikes(self.segnalationObject, likeOrNotLike: -1)
                                dispatch_async(dispatch_get_main_queue()) {
                                    self.notLikeImage.image = UIImage(named: "ThumbsDown")
                                    
                                    self.likeLabel.text = "\(like)"
                                    self.notLikeLabel.text = "\(notLike)"
                                }
                            }
                        } else if (valutationType == 0) {
                            //il record esiste già, era nullo
                            dispatch_async(dispatch_get_global_queue(Int(QOS_CLASS_USER_INITIATED.value), 0)) {
                                Valutazione().updateValutation(currUser, segnalation: self.segnalationObject, likeOrDislike: -1)
                                like = Valutazione().getNumberOfLikesOrDislikes(self.segnalationObject, likeOrNotLike: 1)
                                notLike = Valutazione().getNumberOfLikesOrDislikes(self.segnalationObject, likeOrNotLike: -1)
                                dispatch_async(dispatch_get_main_queue()) {
                                    self.notLikeImage.image = UIImage(named: "ThumbDownFilled")
                                    
                                    self.likeLabel.text = "\(like)"
                                    self.notLikeLabel.text = "\(notLike)"
                                }
                            }
                        } else {
                            //il record esiste già, era like: lo modifico
                            dispatch_async(dispatch_get_global_queue(Int(QOS_CLASS_USER_INITIATED.value), 0)) {
                                Valutazione().updateValutation(currUser, segnalation: self.segnalationObject, likeOrDislike: -1)
                                like = Valutazione().getNumberOfLikesOrDislikes(self.segnalationObject, likeOrNotLike: 1)
                                notLike = Valutazione().getNumberOfLikesOrDislikes(self.segnalationObject, likeOrNotLike: -1)
                                dispatch_async(dispatch_get_main_queue()) {
                                    self.notLikeImage.image = UIImage(named: "ThumbDownFilled")
                                    self.likeImage.image = UIImage(named: "ThumbsUp")
                                    
                                    self.likeLabel.text = "\(like)"
                                    self.notLikeLabel.text = "\(notLike)"
                                }
                            }
                        }
                    } else {
                        //la valutazione non esiste e la inserisco
                        dispatch_async(dispatch_get_global_queue(Int(QOS_CLASS_USER_INITIATED.value), 0)) {
                            Valutazione().insert(-1, user: currUser, segnalation: self.segnalationObject)
                            like = Valutazione().getNumberOfLikesOrDislikes(self.segnalationObject, likeOrNotLike: 1)
                            notLike = Valutazione().getNumberOfLikesOrDislikes(self.segnalationObject, likeOrNotLike: -1)
                            dispatch_async(dispatch_get_main_queue()) {
                                self.notLikeImage.image = UIImage(named: "ThumbDownFilled")
                                
                                self.likeLabel.text = "\(like)"
                                self.notLikeLabel.text = "\(notLike)"
                            }
                        }
                    }
                }
            }
        } else {
            SCLAlertView().showError("Connessione Assente", subTitle: "Controlla che il tuo dispositivo sia connesso ad internet")
        }
    }
    
    //MARK: - Risolta segnalazione
    func solveSegnalation(){
        if (GlobalsMethods().isConnectedToNetwork()) {
            dispatch_async(dispatch_get_global_queue(Int(QOS_CLASS_USER_INITIATED.value), 0)) {
                //thread async
                Segnalazione().updateSolved(self.segnalationObject.objectId! as String, solved: true)
                dispatch_async(dispatch_get_main_queue()) {
                    SCLAlertView().showCustomSuccess("Risolto", subTitle: "Segnalazione contrassegnata come risolta", colorStyle: 0x00796B, colorTextButton: 0xFFFFFF)
                    self.navigationController?.popViewControllerAnimated(true)
                }
            }
        } else {
            SCLAlertView().showError("Connessione assente", subTitle: "Controlla che il tuo dispositivo sia connesso a internet")
        }
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
            facebookPost.addImage(segnalationPhoto.image)
            
            self.presentViewController(facebookPost, animated: true, completion: nil)
            
        } else {
            SCLAlertView().showWarning("Accesso non effettuato", subTitle: "Accedere a Facebook in\nImpostazioni -> Facebook\nper condividere")
        }
    }
    
    func shareTwitter() {
        if SLComposeViewController.isAvailableForServiceType(SLServiceTypeTwitter) {
            
            var tweetShare:SLComposeViewController = SLComposeViewController(forServiceType: SLServiceTypeTwitter)
            tweetShare.setInitialText("\(segnalationObject[Segnalazione.title] as! String) - Segnalazione scritta da \(user[Utente.name] as! String) con Repair City")
            tweetShare.addImage(segnalationPhoto.image)
            self.presentViewController(tweetShare, animated: true, completion: nil)
            
        } else {
            SCLAlertView().showWarning("Accesso non effettuato", subTitle: "Accedere a Twitter in\nImpostazioni -> Twitter\nper condividere")
        }
    }
}