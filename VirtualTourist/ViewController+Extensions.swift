//
//  ViewController+Extensions.swift
//  VirtualTourist
//
//  Created by Online Training on 6/14/17.
//  Copyright © 2017 Mitch Salcido. All rights reserved.
//
/*
 About ViewController+Extensions.swift:
 */

import UIKit

// alerts
extension UIViewController {
    
    // procced/cancel alert
    func presentProceedCancelAlert(title: String? = nil, message: String? = nil, completion: ((UIAlertAction) -> Void)?) {
       
        /*
         Alert controller: Create and present an alert with a "Procced" button and a "Cancel" button.
         Pressing the Proceed with fire the completion.
        */
        
        let alert = UIAlertController(title: title,
                                      message: message,
                                      preferredStyle: .alert)
        
        let proceedAction = UIAlertAction(title: "Proceed", style: .destructive, handler: completion)
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        alert.addAction(cancelAction)
        alert.addAction(proceedAction)
        present(alert, animated: true)
    }
    
    // cancel alert
    func presentCancelAlert(title: String, message: String? = nil, completion: ((UIAlertAction) -> Void)?) {
        
        /*
         Alert controller: Create and present an alert with "Cancel" button.
         Pressing Cancel will fire the completion.
         */
        
        let alert = UIAlertController(title: title,
                                      message: message,
                                      preferredStyle: .alert)
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: completion)
        alert.addAction(cancelAction)
        present(alert, animated: true)
    }
    
    // Alert for error handling
    func presentAlertForError(_ error: VTError) {
        
        /*
         Alert controller: Create and present an alert with "OK" button..used to provide user feedback for error
         */
        
        var alertTitle: String!
        var alertMessage: String!
        switch error {
        case .locationError(let value):
            alertTitle = "Location Error"
            alertMessage = value
        case .generalError(let value):
            alertTitle = "General Error"
            alertMessage = value
        case .networkError(let value):
            alertTitle = "Network Error"
            alertMessage = value
        case .operatorError(let value):
            alertTitle = "Operator Error"
            alertMessage = value
        case .coreData(let value):
            alertTitle = "Core Data Error"
            alertMessage = value
        }
        
        let alert = UIAlertController(title: alertTitle, message: alertMessage, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// related to core data and Flick downloading
extension UIViewController {
    
}
