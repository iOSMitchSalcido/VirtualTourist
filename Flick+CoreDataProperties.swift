//
//  Flick+CoreDataProperties.swift
//  VirtualTourist
//
//  Created by Online Training on 6/23/17.
//  Copyright © 2017 Mitch Salcido. All rights reserved.
//

import Foundation
import CoreData


extension Flick {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Flick> {
        return NSFetchRequest<Flick>(entityName: "Flick")
    }

    @NSManaged public var image: NSData?
    @NSManaged public var urlString: String?
    @NSManaged public var pin: Pin?

}
