//
//  Segnalazione.swift
//  Repair City
//
//  Created by InfinityCode on 29/07/15.
//  Copyright (c) 2015 InfinityCode. All rights reserved.
//

import Foundation
import Parse
import Bolts

class Segnalazione {
    
    static let className = "Segnalazione"
    static let title = "titolo"
    static let description = "descrizione"
    static let priority = "gravita"
    static let position = "posizione"
    static let solved = "risolto"
    static let objectId = "objectId"
    static let updatedDate = "updatedAt"
    static let segnalationPhoto = "fotoSegnalazione"
    static let user = "utenteCollegato"
    static let localDataUUID = "codiceFotoLocale"
    static let segnalationNotSaved = "newSegnalation"
    
    // MARK: - Inserimento da nuova segnalazione
    func insert(title: String, description: String, priority: Int, latitude: Double, longitude: Double, segnalationPhoto: NSData, user: PFObject) -> Bool {
        var checkSavingLocal = false
        var checkSavingOnline = false
        var newSegnalation = PFObject(className: Segnalazione.className)
        newSegnalation[Segnalazione.title] = title
        newSegnalation[Segnalazione.description] = description
        newSegnalation[Segnalazione.priority] = priority
        newSegnalation[Segnalazione.position] = PFGeoPoint(latitude: latitude, longitude: longitude)
        newSegnalation[Segnalazione.solved] = false
        newSegnalation[Segnalazione.segnalationPhoto] = PFFile(name: "\(NSUUID().UUIDString).png", data: segnalationPhoto)
        newSegnalation[Segnalazione.user] = user
        
        checkSavingOnline = newSegnalation.save()
        if (!checkSavingOnline) {
            var uuid = NSUUID().UUIDString
            newSegnalation[Segnalazione.localDataUUID] = uuid
            newSegnalation.pinWithName(Segnalazione.segnalationNotSaved)
            GlobalsMethods().writeOnNSUserDefaults(GlobalVariables.keyPreferencesSegnalationPhotos, value: segnalationPhoto, uuid: uuid)
        } else {
            newSegnalation.pin()
        }
        return checkSavingOnline
    }

    // MARK: - Getter
    func getSegnalationsInRange(userLocation: PFGeoPoint) -> [PFObject] {
        let query = PFQuery(className: Segnalazione.className)
        query.fromLocalDatastore()
        var range = Double(GlobalsMethods().getSegnalationRangeOnNSUserDefaults(GlobalVariables.keyPreferencesSegnalationRange))
        query.whereKey(Segnalazione.position, nearGeoPoint: userLocation, withinKilometers: range)
        query.whereKey(Segnalazione.solved, equalTo: false)
        let results = query.findObjects()
        return results as! [PFObject]
    }
    
    func getSegnalationsOrderedByPriority() -> [PFObject] {
        let query = PFQuery(className: Segnalazione.className)
        query.fromLocalDatastore()
        query.whereKey(Segnalazione.solved, equalTo: false)
        query.orderByDescending(Segnalazione.priority)
        let results = query.findObjects()
        return results as! [PFObject]
    }
    
    func getSegnalationsOrderedByDate() -> [PFObject] {
        let query = PFQuery(className: Segnalazione.className)
        query.fromLocalDatastore()
        query.whereKey(Segnalazione.solved, equalTo: false)
        query.orderByDescending(Segnalazione.updatedDate)
        let results = query.findObjects()
        return results as! [PFObject]
    }
    
    func getSegnalationsOrderedByPopularity() -> [PFObject] {
        //prendo tutte le segnalazione
        let query = PFQuery(className: Segnalazione.className)
        query.fromLocalDatastore()
        query.whereKey(Segnalazione.solved, equalTo: false)
        let results = query.findObjects() as! [PFObject]
        
        var dictionary = Dictionary<String, Int> ()
        
        //creo la query popularity che mi prende tutte le valutazioni associate ad una segnalazione
        let queryPopularity = PFQuery(className: Valutazione.className)
        queryPopularity.fromLocalDatastore()
        //eseguo la query popularity per ogni record preso dalla prima query
        for record in results {
            queryPopularity.whereKey(Valutazione.segnalation, equalTo: record)
            queryPopularity.whereKey(Valutazione.likeNotLike, notEqualTo: 0)
            let value = queryPopularity.countObjects()
            var objectId: String = record.objectId!
            //chiave: segnalazione -> valore: numero di valutazioni positive/negative
            dictionary[objectId] = value
        }
        
        //ordinare il dictionary
        var sortedObject: [PFObject] = []
        for (key,value) in (Array(dictionary).sorted {$0.1 < $1.1}) {
            let value = "[\"\(key)\": \"\(value)\"]"
            var object: PFObject = getSegnalationFromObjectID(key)!
            sortedObject.append(object)
        }
        
        return sortedObject.reverse()
    }
    
    func getSegnalationFromObjectID(segnalationObjectId: String) -> PFObject? {
        let query = PFQuery(className: Segnalazione.className)
        query.fromLocalDatastore()
        query.whereKey(Segnalazione.objectId, equalTo: segnalationObjectId)
        return query.getFirstObject()
    }
    
    func getSegnalationsOfAnUser(user: PFObject, solved: Bool?) -> [PFObject] {
        let query = PFQuery(className: Segnalazione.className)
        query.fromLocalDatastore()
        query.whereKey(Segnalazione.user, equalTo: user)
        if (solved != nil) {
            query.whereKey(Segnalazione.solved, equalTo: solved!)
        }
        let results = query.findObjects() as! [PFObject]
        return results
    }
    
    func updateSolved(segnalationId: String, solved: Bool) {
        let query = PFQuery(className: Segnalazione.className)
        query.fromLocalDatastore()
        query.whereKey(Segnalazione.objectId, equalTo: segnalationId)
        var result = query.getFirstObject()
        result![Segnalazione.solved] = solved
        result!.save()
        result!.pin()
    }
    
    // MARK: - Scarica i dati presenti online
    func updateWithOnline(userLocation: PFGeoPoint) -> [PFObject] {
        var range = Double(GlobalsMethods().getSegnalationRangeOnNSUserDefaults(GlobalVariables.keyPreferencesSegnalationRange))
        
        let firstQuery = PFQuery(className: Segnalazione.className)
        firstQuery.whereKey(Segnalazione.position, nearGeoPoint: userLocation, withinKilometers: range)
        let results = firstQuery.findObjects() as! [PFObject]
        
        let secondQuery = PFQuery(className: Segnalazione.className)
        secondQuery.fromLocalDatastore()
        secondQuery.whereKey(Segnalazione.objectId, doesNotMatchQuery: firstQuery)
        
        let resultsSecondQuery = secondQuery.findObjects() as! [PFObject]
        
        for record in resultsSecondQuery {
            record.unpin()
        }

        for segnalation in results {
            segnalation.pin()
        }
        return results
    }
    
    // MARK: - Sincronizzazione dati locali non salvati online
    func syncingLocalChanges() {
        let query = PFQuery(className:Segnalazione.className)
        query.fromLocalDatastore()
        query.fromPinWithName(Segnalazione.segnalationNotSaved)
        query.findObjectsInBackground().continueWithBlock( {
            (task: BFTask!) -> AnyObject! in
            
            let segnalations = task.result as! NSArray
            for segnalation in segnalations {
                var objectSegnalation = segnalation as! PFObject
                let data = GlobalsMethods().getDataOnNSUserDefaults(GlobalVariables.keyPreferencesSegnalationPhotos, uuid: segnalation[Segnalazione.localDataUUID] as! String)
                let imageFile = PFFile(name: "\(segnalation[Segnalazione.localDataUUID] as! String).png", data: data!)
                objectSegnalation[Segnalazione.segnalationPhoto] = imageFile
                
                segnalation.unpinWithName(Segnalazione.segnalationNotSaved)
                
                objectSegnalation.pin()
                
                objectSegnalation.saveInBackgroundWithBlock( {
                    (success: Bool, error: NSError?) -> Void in
                    if (success) {
                        //Non c'è bisogno di fare niente con i PFObject perchè fa gia il pin sincrono prima
                        GlobalsMethods().removeDataOnNSUserDefaults(GlobalVariables.keyPreferencesSegnalationPhotos, uuid: segnalation[Segnalazione.localDataUUID] as! String)
                    } else {
                        objectSegnalation.unpin()
                        objectSegnalation.pinWithName(Segnalazione.segnalationNotSaved)
                    }
                })
                
            }
            return task
        })
    }
}