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
