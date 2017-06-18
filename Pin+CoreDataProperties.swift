//
//  Pin+CoreDataProperties.swift
//  VirtualTourist
//
//  Created by Online Training on 6/17/17.
//  Copyright © 2017 Mitch Salcido. All rights reserved.
//

import Foundation
import CoreData


extension Pin {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Pin> {
        return NSFetchRequest<Pin>(entityName: "Pin")
    }

    @NSManaged public var title: String?
    @NSManaged public var flicks: NSSet?
    @NSManaged public var coordinate: Coordinate?

}

// MARK: Generated accessors for flicks
extension Pin {

    @objc(addFlicksObject:)
    @NSManaged public func addToFlicks(_ value: Flick)

    @objc(removeFlicksObject:)
    @NSManaged public func removeFromFlicks(_ value: Flick)

    @objc(addFlicks:)
    @NSManaged public func addToFlicks(_ values: NSSet)

    @objc(removeFlicks:)
    @NSManaged public func removeFromFlicks(_ values: NSSet)

}
