//
//  Valutazione.swift
//  Repair City
//
//  Created by InfinityCode on 29/07/15.
//  Copyright (c) 2015 InfinityCode. All rights reserved.
//

import Foundation
import Parse

class Valutazione {
    
    static let className = "Valutazione"
    static let likeNotLike = "like_NotLike"
    static let user = "utenteCollegato"
    static let segnalation = "segnalazioneCollegata"
    static let creationDate = "createdAt"
    static let updatedDate = "updatedAt"
    static let objectId = "objectId"
    
    static let valutationNotSaved = "newValutation"
    
    // MARK: - Inserimento di una nuova valutazione
    func insert(likeNotLike: Int, user: PFObject, segnalation: PFObject) {
        var checkSavingLocal = false
        var checkSavingOnline = false
        var newValutation = PFObject(className: Valutazione.className)
        newValutation[Valutazione.likeNotLike] = likeNotLike
        newValutation[Valutazione.user] = user
        newValutation[Valutazione.segnalation] = segnalation
        
        checkSavingOnline = newValutation.save()
        if (!checkSavingOnline) {
            newValutation.pinWithName(Valutazione.valutationNotSaved)
        } else {
            newValutation.pin()
        }
        
    }
    
    // MARK: - Controllo se esiste la valutazione
    func checkValutationExistOnline(objectIdUser: PFObject, segnalation: PFObject) -> Bool {
        let query = PFQuery(className: Valutazione.className)
        query.whereKey(Valutazione.user, equalTo: objectIdUser)
        query.whereKey(Valutazione.segnalation, equalTo: segnalation)
        if (query.getFirstObject() != nil) {
            return true
        }
        return false
    }
    
    func checkValutationExistLocal(objectIdUser: PFObject, segnalation: PFObject) -> Bool {
        let query = PFQuery(className: Valutazione.className)
        query.fromLocalDatastore()
        query.whereKey(Valutazione.user, equalTo: objectIdUser)
        query.whereKey(Valutazione.segnalation, equalTo: segnalation)
        if (query.getFirstObject() != nil) {
            return true
        }
        return false
    }
    
    // MARK: - Getter
    func getValutationFromObjectID(valutationObjectId: String) -> PFObject? {
        let query = PFQuery(className: Valutazione.className)
        query.fromLocalDatastore()
        query.whereKey(Valutazione.objectId, equalTo: valutationObjectId)
        return query.getFirstObject()
    }
    
    func getValutationType(user: PFObject, segnalation: PFObject) -> Int {
        if (checkValutationExistLocal(user, segnalation: segnalation)) {
            let query = PFQuery(className: Valutazione.className)
            query.fromLocalDatastore()
            query.whereKey(Valutazione.user, equalTo: user)
            query.whereKey(Valutazione.segnalation, equalTo: segnalation)
            let result = query.getFirstObject()
            return result![Valutazione.likeNotLike] as! Int
        } else {
            return 0
        }
    }
    
    func getNumberOfLikesOrDislikes(segnalation: PFObject?, likeOrNotLike: Int) -> Int {
        let query = PFQuery(className: Valutazione.className)
        query.fromLocalDatastore()
        if (segnalation != nil) {
            query.whereKey(Valutazione.segnalation, equalTo: segnalation!)
        }
        query.whereKey(Valutazione.likeNotLike, equalTo: likeOrNotLike)
        let results = query.countObjects()
        return results
    }
    
    func getNumberOfLikeOrDislikesOfAnUser(user: PFObject, likeOrNotLike: Int) -> Int {
        let segnalations = Segnalazione().getSegnalationsOfAnUser(user, solved: nil)
        var counter: Int = 0
        for segnalation in segnalations {
            counter += getNumberOfLikesOrDislikes(segnalation, likeOrNotLike: likeOrNotLike)
        }
        return counter
    }
    
    func updateValutation(user: PFObject, segnalation: PFObject, likeOrDislike: Int) {
        let query = PFQuery(className: Valutazione.className)
        query.fromLocalDatastore()
        query.whereKey(Valutazione.user, equalTo: user)
        query.whereKey(Valutazione.segnalation, equalTo: segnalation)
        var result = query.getFirstObject()
        result![Valutazione.likeNotLike] = likeOrDislike
        result!.save()
        result!.pin()
    }
    
    // MARK: - Scarica i dati presenti online
    func updateWithOnline(segnalationsArray: [PFObject]) -> [PFObject] {
        
        let query = PFQuery(className: Valutazione.className)
        query.whereKey(Valutazione.segnalation, containedIn: segnalationsArray)
        let results = query.findObjects() as! [PFObject]
        
        for valutation in results {
            valutation.pin()
        }
        return results
    }
}
