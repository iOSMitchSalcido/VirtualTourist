//
//  AppInfoViewController.swift
//  VirtualTourist
//
//  Created by Online Training on 9/10/17.
//  Copyright © 2017 Mitch Salcido. All rights reserved.
//
/*
 AppInfoViewController.swift
 Handle image swap for imageViews in AppInfoVC
 */
import UIKit

class AppInfoViewController: UIViewController {

    // ref to imageViews
    @IBOutlet weak var appInfoImageView: UIImageView!
    @IBOutlet weak var appInstructionsImageView: UIImageView!
    
    // handle image swap..info/instruct images are different depending on orientation
    override func viewWillLayoutSubviews() {
        
        if view.bounds.size.width < view.bounds.size.height {
            // portrait
            appInfoImageView.image = UIImage(named: "AppInfoTitle_portrait")
            appInstructionsImageView.image = UIImage(named: "AppInfoInstructions_portrait")
        }
        else {
            // landscape
            appInfoImageView.image = UIImage(named: "AppInfoTitle_landscape")
            appInstructionsImageView.image = UIImage(named: "AppInfoInstructions_landscape")
        }
    }
}
