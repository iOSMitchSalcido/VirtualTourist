//
//  AppHelpViewController.swift
//  VirtualTourist
//
//  Created by Online Training on 8/6/17.
//  Copyright © 2017 Mitch Salcido. All rights reserved.
//
/*
 AppHelpViewController.swift
 
 Handle dismiss of info/help VC
*/

import UIKit

class AppHelpViewController: UIViewController {
        
    // doneBbi pressed. Dismiss VC
    @IBAction func doneBbiPressed(_ sender: Any) {
        dismiss(animated: true)
    }
}
