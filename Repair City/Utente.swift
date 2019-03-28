//
//  Utente.swift
//  Repair City
//
//  Created by InfinityCode on 28/07/15.
//  Copyright (c) 2015 InfinityCode. All rights reserved.
//

import Foundation
import Parse
import Bolts

class Utente {
    
    //MARK: - Campi dell'entità Utente
    static let className = "Utente"
    static let facebookID = "facebookID"
    static let name = "nome"
    static let mail = "mail"
    static let profilePhoto = "fotoProfilo"
    static let creationDate = "createdAt"
    static let objectId = "objectId"
    
    //MARK: - varibile per il pin e unpin degli oggetti non salvati online per mancanza di connessione
    static let userNotSaved = "newUser"
    
    // MARK: - Inserimento di un utente (Utilizzato nella loginView)
    func login(dictionary: NSDictionary) -> Bool {
        var checkSavingLocal = false
        var checkSavingOnline = false
        var checkExistOnline = self.checkUserExistOnline(dictionary.valueForKey("id") as! String)
        if (!checkExistOnline) {
            var newUser = PFObject(className: Utente.className)
            var id = dictionary.valueForKey("id") as! String
            for (key, value) in dictionary {
                switch (key as! String) {
                case "name":
                    newUser[Utente.name] = value as! String
                    break
                case "id":
                    newUser[Utente.facebookID] = value as! String
                    id = value as! String
                    break
                case "email":
                    newUser[Utente.mail] = value as! String
                    break
                case "picture":
                    let data = getProfilePhotoOnline(id)
                    let imageFile = PFFile(name: id + ".png", data: data!)
                    newUser[Utente.profilePhoto] = imageFile
                    break
                default:
                    break
                }
            }
            
            checkSavingOnline = newUser.save()
            if (!checkSavingOnline) {
                checkSavingLocal = newUser.pinWithName(Utente.userNotSaved)
            } else {
                checkSavingLocal = newUser.pin()
            }
            GlobalsMethods().writeOnNSUserDefaults(GlobalVariables.ketPreferencesFirstLaunch, value: true)
        }else {
            if (getLocalUserObject(dictionary.valueForKey("id") as! String) == nil){
                GlobalsMethods().writeOnNSUserDefaults(GlobalVariables.ketPreferencesFirstLaunch, value: true)
            }else{
                GlobalsMethods().writeOnNSUserDefaults(GlobalVariables.ketPreferencesFirstLaunch, value: false)
            }
            var onlineUser = getUserOnline(dictionary.valueForKey("id") as! String)
            onlineUser?.pin()
        }
        if (checkExistOnline || checkSavingLocal || checkSavingOnline) {
            GlobalsMethods().writeOnNSUserDefaults(GlobalVariables.keyPreferencesFB, value: dictionary.valueForKey("id") as! String)
        }
        return checkExistOnline || checkSavingLocal || checkSavingOnline
    }
    
    // MARK: - Controllo se utente esiste online
    func checkUserExistOnline(facebookID: String) -> Bool {
        let query = PFQuery(className: Utente.className)
        query.whereKey(Utente.facebookID, equalTo: facebookID)
        if (query.getFirstObject() != nil) {
            return true
        }
        return false
    }
    
    func checkUserExistLocal(objectId: String) -> Bool {
        let query = PFQuery(className: Utente.className)
        query.fromLocalDatastore()
        query.whereKey(Utente.objectId, equalTo: objectId)
        if (query.getFirstObject() != nil) {
            return true
        }
        return false
    }
    
    // MARK: - Getter
    func getUserOnline(facebookID: String) -> PFObject? {
        let query = PFQuery(className: Utente.className)
        query.whereKey(Utente.facebookID, equalTo: facebookID)
        return query.getFirstObject()
    }
    
    func getLocalUserObject(facebookID : String) -> PFObject?{
        let query = PFQuery(className: Utente.className)
        query.fromLocalDatastore()
        query.whereKey(Utente.facebookID, equalTo: facebookID)
        return query.getFirstObject()
    }
    
    func getUserProfilePhoto(user : PFObject) -> UIImage?{
        let userImageFile = user[Utente.profilePhoto] as! PFFile
        var imageData = userImageFile.getData()
        if (imageData == nil){
            imageData = getProfilePhotoOnline(user[Utente.facebookID] as! String)
        }
        if (imageData == nil){
            return nil
        }else{
            return UIImage(data: imageData!)
        }
    }
    
    func getUserFromObjectID(userObjectId: String) -> PFObject? {
        let query = PFQuery(className: Utente.className)
        query.fromLocalDatastore()
        query.whereKey(Utente.objectId, equalTo: userObjectId)
        return query.getFirstObject()
    }
    
    func getProfilePhotoOnline(facebookID : String) -> NSData? {
        let url = NSURL(string: "https://graph.facebook.com/\(facebookID)/picture?width=200&height=200")
        return NSData(contentsOfURL: url!)
    }
    
    // MARK: - Scarica i dati presenti online
    func updateWithOnline(objectIDArray: [String]) -> [PFObject] {
        let query = PFQuery(className: Utente.className)
        query.whereKey(Utente.objectId, containedIn: objectIDArray)
        let results = query.findObjects() as! [PFObject]
        
        for record in results {
            record.pin()
        }
        
        return results
    }
    
    // MARK: - Sincronizzazione dati locali non salvati online
    func syncingLocalChanges() {
        let query = PFQuery(className:Utente.className)
        query.fromLocalDatastore()
        query.fromPinWithName(Utente.userNotSaved)
        query.findObjectsInBackground().continueWithBlock( {
            (task: BFTask!) -> AnyObject! in
            
            let users = task.result as! NSArray
            for user in users {
                var objectUser = user as! PFObject
                let data = self.getProfilePhotoOnline(user[Utente.facebookID] as! String)
                let imageFile = PFFile(name: "\(user[Utente.facebookID] as! String).png", data: data!)
                objectUser[Utente.profilePhoto] = imageFile
                user.unpinWithName(Utente.userNotSaved)
                objectUser.pin()
                objectUser.saveInBackgroundWithBlock({
                    (success: Bool, error: NSError?) -> Void in
                    if (success) {
                        //Non c'è bisogno di fare niente perchè fa gia il pin sincrono prima
                    } else {
                        objectUser.unpin()
                        objectUser.pinWithName(Utente.userNotSaved)
                    }
                })
                
            }
            return task
        })
    }
    
}
