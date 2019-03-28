//
//  Global.swift
//  Repair City
//
//  Created by InfinityCode on 24/07/15.
//  Copyright (c) 2015 InfinityCode. All rights reserved.
//

import Foundation
import UIKit
import SystemConfiguration
import CoreLocation
import AVFoundation
import AssetsLibrary
import AddressBookUI
import MapKit

//MARK: - Variabili Globali
class GlobalVariables {
    
    static let keyPreferencesFB = "facebookID"
    static let keyPreferencesMap = "mapType"
    static let keyPreferencesSegnalationPhotos = "segnalationPhotos"
    static let keyPreferencesPreviousView = "previousView"
    static let keyPreferencesDispatchActive = "dispatchActive"
    static let ketPreferencesFirstLaunch = "firstLaunch"
    static let keyPreferencesSegnalationRange = "segnalationRange"
    static let keyPreferencesForcedSync = "forcedSync"
    
}

// MARK: - Metodi Globali
class GlobalsMethods {
    
    let preferences = NSUserDefaults.standardUserDefaults()
    
    //MARK: - Metodi che lavorano su NSUserDefaults
    // WRITE
    func writeOnNSUserDefaults(key : String , value : String){
        preferences.setObject(value, forKey: key)
    }
    
    func writeOnNSUserDefaults(key : String , value : UInt){
        preferences.setObject(value, forKey: key)
    }
    
    func writeOnNSUserDefaults (key: String, value: NSData, uuid: String) {
        var dictionary = preferences.objectForKey(key) as? NSDictionary
        dictionary = [uuid : value]
        preferences.setObject(dictionary, forKey: key)
    }
    
    func writeOnNSUserDefaults (key : String , value : Int) {
        preferences.setInteger(value, forKey: key)
    }
    
    func writeOnNSUserDefaults (key : String , value : Bool) {
        preferences.setBool(value, forKey: key)
    }
    
    // GET
    func getUserOnNSUserDefaults(key : String) -> String? {
        return preferences.objectForKey(key) as? String
    }
    
    func getMapOnNSUserDefaults(key : String) -> UInt? {
        return preferences.objectForKey(key) as? UInt
    }
    
    func getDataOnNSUserDefaults (key: String, uuid: String) -> NSData? {
        var dictionary = preferences.objectForKey(key) as? NSDictionary
        return dictionary!.valueForKey(uuid) as? NSData
    }
    
    func getBoolOnNSUserDefaults(key: String) -> Bool {
        return preferences.boolForKey(key)
    }
    
    func getPreviousViewOnNSUserDefaults(key: String) -> Int?{
        return preferences.objectForKey(key) as? Int
    }
    
    func getSegnalationRangeOnNSUserDefaults (key: String) -> Int {
        return preferences.objectForKey(key) as! Int
    }
    
    // REMOVE
    func removeOnNSUserDefaults(key : String){
        preferences.removeObjectForKey(key)
    }
    
    func removeDataOnNSUserDefaults(key: String, uuid: String) {
        var dictionary = preferences.objectForKey(key) as? NSMutableDictionary
        dictionary?.removeObjectForKey(uuid)
        preferences.setObject(dictionary, forKey: key)
    }
    
    //MARK: - Ricavare UIColor da un HEX
    func UIColorFromRGB(rgbValue: UInt) -> UIColor {
        return UIColor(
            red: CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0,
            green: CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0,
            blue: CGFloat(rgbValue & 0x0000FF) / 255.0,
            alpha: CGFloat(1.0)
        )
    }
    
    //MARK: - Controllo stato gps
    func getGPSAutorizationStatus() -> Bool {
        if (CLLocationManager.locationServicesEnabled()) {
            var checkFirstUse = getBoolOnNSUserDefaults(GlobalVariables.ketPreferencesFirstLaunch)
            switch CLLocationManager.authorizationStatus() {
            case .AuthorizedWhenInUse, .AuthorizedAlways:
                return true
            case .NotDetermined:
                if (!checkFirstUse){
                    var alertView = SCLAlertView()
                    alertView.addButton("Impostazioni"){
                        if let url = NSURL(string:UIApplicationOpenSettingsURLString) {
                            UIApplication.sharedApplication().openURL(url)
                        }
                    }
                    alertView.showWarning("Attenzione", subTitle: "Autorizza l'applicazione ad utilizzare la localizzazione")
                }
                return false
            case .Restricted, .Denied:
                if (!checkFirstUse){
                    var alertView = SCLAlertView()
                    alertView.addButton("Impostazioni"){
                        if let url = NSURL(string:UIApplicationOpenSettingsURLString) {
                            UIApplication.sharedApplication().openURL(url)
                        }
                    }
                    alertView.showWarning("Attenzione", subTitle: "Autorizza l'applicazione ad utilizzare la localizzazione")
                }
                return false
            default:
                break
            }
        } else {
            SCLAlertView().showWarning("Attenzione", subTitle: "Attiva la localizzazione sul tuo dispositivo")
        }
        return false
    }
    
    //MARK: - Controllo autorizzazioni fotocamera
    func getCameraStatus() -> Bool{
        var status : AVAuthorizationStatus = AVCaptureDevice.authorizationStatusForMediaType(AVMediaTypeVideo)
        switch (status){
        case .NotDetermined:
            return true
        case .Restricted, .Denied:
            var alertView = SCLAlertView()
            alertView.addButton("Impostazioni"){
                if let url = NSURL(string:UIApplicationOpenSettingsURLString) {
                    UIApplication.sharedApplication().openURL(url)
                }
            }
            alertView.showWarning("Attenzione", subTitle: "Autorizza l'applicazione ad utilizzare la fotocamera")
            return false
        case .Authorized:
            return true
        }
    }
    
    //MARK: - Controllo autorizzazioni libreria foto
    func getPhotoLibraryStatus() -> Bool{
        var status : ALAuthorizationStatus = ALAssetsLibrary.authorizationStatus()
        switch (status){
        case .NotDetermined:
            return true
        case .Restricted, .Denied:
            var alertView = SCLAlertView()
            alertView.addButton("Impostazioni"){
                if let url = NSURL(string:UIApplicationOpenSettingsURLString) {
                    UIApplication.sharedApplication().openURL(url)
                }
            }
            alertView.showWarning("Attenzione", subTitle: "Autorizza l'applicazione ad utilizzare il rullino")
            return false
        case .Authorized:
            return true
        }
    }
    
    //MARK: - Controllo autorizzazione contatti
    func getAddressBookStatus() -> Bool{
        let authorizationStatus = ABAddressBookGetAuthorizationStatus()
        switch (authorizationStatus) {
        case .Denied, .Restricted:
            var alertView = SCLAlertView()
            alertView.addButton("Impostazioni"){
                if let url = NSURL(string:UIApplicationOpenSettingsURLString) {
                    UIApplication.sharedApplication().openURL(url)
                }
            }
            alertView.showWarning("Attenzione", subTitle: "Autorizza l'applicazione ad utilizzare i contatti")
            return false
        case .Authorized:
            return true
        case .NotDetermined:
            return true
            
        }
    }
    
    // MARK: - Controllo connessione internet
    func isConnectedToNetwork() -> Bool {
        
        var zeroAddress = sockaddr_in(sin_len: 0, sin_family: 0, sin_port: 0, sin_addr: in_addr(s_addr: 0), sin_zero: (0, 0, 0, 0, 0, 0, 0, 0))
        zeroAddress.sin_len = UInt8(sizeofValue(zeroAddress))
        zeroAddress.sin_family = sa_family_t(AF_INET)
        
        let defaultRouteReachability = withUnsafePointer(&zeroAddress) {
            SCNetworkReachabilityCreateWithAddress(nil, UnsafePointer($0)).takeRetainedValue()
        }
        
        var flags: SCNetworkReachabilityFlags = 0
        if SCNetworkReachabilityGetFlags(defaultRouteReachability, &flags) == 0 {
            return false
        }
        
        let isReachable = (flags & UInt32(kSCNetworkFlagsReachable)) != 0
        let needsConnection = (flags & UInt32(kSCNetworkFlagsConnectionRequired)) != 0
        
        return isReachable && !needsConnection
    }    
}