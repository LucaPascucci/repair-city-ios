//
//  LoginViewController.swift
//  Repair City
//
//  Created by InfinityCode on 26/07/15.
//  Copyright (c) 2015 InfinityCode. All rights reserved.
//

import Foundation
import UIKit
import FBSDKCoreKit
import FBSDKLoginKit
import Parse

class LoginViewController: UIViewController {
    
    //MARK:
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    //MARK: - Nascondo la Status Bar
    override func prefersStatusBarHidden() -> Bool {
        return true
    }
    
    // MARK: - Facebook Login
    @IBAction func loginWithFacebook(sender: AnyObject) {
        if (GlobalsMethods().isConnectedToNetwork()){
            var fbLoginManager : FBSDKLoginManager = FBSDKLoginManager()
            fbLoginManager.logInWithReadPermissions(["email"], handler: { (result, error) -> Void in
                if (error == nil){
                    var fbloginresult : FBSDKLoginManagerLoginResult = result
                    if(fbloginresult.grantedPermissions.contains("email"))
                    {
                        self.getFBUserData()
                    }
                }
            })
        }else{
            SCLAlertView().showError("Connessione Assente", subTitle: "Controlla che il tuo dispositivo sia connesso ad internet")
        }
    }
    
    func getFBUserData(){
        if((FBSDKAccessToken.currentAccessToken()) != nil){
            FBSDKGraphRequest(graphPath: "me", parameters: ["fields": "id, name, first_name, last_name, picture.type(large), email"]).startWithCompletionHandler({ (connection, result, error) -> Void in
                if (error == nil){
                     var waitAlert = SCLAlertView().showTitle("Caricamento", subTitle: "Sto accedendo...", duration: 0.0, completeText: "", style: .Wait , colorStyle: 0x00796B, colorTextButton: 0x4D4D4D)
                    //crea un thread async
                    dispatch_async(dispatch_get_global_queue(Int(QOS_CLASS_USER_INITIATED.value), 0)) {
                        //operazioni che esegue il thread
                        var returnLogin = Utente().login(result as! NSDictionary)
                        dispatch_async(dispatch_get_main_queue()) {
                            if (returnLogin){
                                waitAlert.close()
                                self.navigateToHome()
                            }
                        }
                    }
                }
            })
        }
    }

    //MARK: - Navigatori
    func navigateToHome(){
        let storyBoard : UIStoryboard = UIStoryboard(name: "Main", bundle:nil)
        let nextViewController = storyBoard.instantiateViewControllerWithIdentifier("TabBar") as! UIViewController
        self.presentViewController(nextViewController, animated:true, completion:nil)
    }

}