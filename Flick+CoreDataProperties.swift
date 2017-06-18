//
//  Flick+CoreDataProperties.swift
//  VirtualTourist
//
//  Created by Online Training on 6/17/17.
//  Copyright © 2017 Mitch Salcido. All rights reserved.
//

import Foundation
import CoreData


extension Flick {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Flick> {
        return NSFetchRequest<Flick>(entityName: "Flick")
    }

    @NSManaged public var image: NSObject?
    @NSManaged public var urlString: String?
    @NSManaged public var pin: Pin?

}
