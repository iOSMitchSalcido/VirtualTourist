//
//  Coordinate+CoreDataProperties.swift
//  VirtualTourist
//
//  Created by Online Training on 6/23/17.
//  Copyright © 2017 Mitch Salcido. All rights reserved.
//

import Foundation
import CoreData


extension Coordinate {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Coordinate> {
        return NSFetchRequest<Coordinate>(entityName: "Coordinate")
    }

    @NSManaged public var latitude: Double
    @NSManaged public var longitude: Double
    @NSManaged public var pin: Pin?

}
