//
//  PinSegnalazione.swift
//  Repair City
//
//  Created by InfinityCode on 01/08/15.
//  Copyright (c) 2015 InfinityCode. All rights reserved.
//

import Foundation
import MapKit
import Parse

class PinSegnalazione: NSObject, MKAnnotation {
    
    //obbligati da MKAnnotation
    let title: String
    let subtitle: String
    let coordinate: CLLocationCoordinate2D
    let UUID: String
    let preview: UIImage
    let priority: Int
    
    var segnalation: PFObject
    
    init(title: String, description: String, coordinate: CLLocationCoordinate2D, segnalationObject: PFObject, identifier: String, preview: UIImage, priority: Int) {
        self.segnalation = segnalationObject
        self.title = title
        self.subtitle = description
        self.coordinate = coordinate
        self.UUID = identifier
        self.preview = preview
        self.priority = priority
        super.init()
    }
}
