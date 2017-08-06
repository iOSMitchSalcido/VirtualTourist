//
//  Pin+CoreDataClass.swift
//  VirtualTourist
//
//  Created by Online Training on 7/15/17.
//  Copyright © 2017 Mitch Salcido. All rights reserved.
//

import Foundation
import CoreData

@objc(Pin)
public class Pin: NSManagedObject {
    
    // property to determine if download was completed
    // ...all flicks have non-nil image data
    var downloadComplete: Bool {
        get {
            for flick in self.flicks! {
                if (flick as! Flick).image == nil {
                    return false
                }
            }
            return true
        }
    }
}
