//
//  Pin+CoreDataProperties.swift
//  VirtualTourist
//
//  Created by Online Training on 7/15/17.
//  Copyright © 2017 Mitch Salcido. All rights reserved.
//

import Foundation
import CoreData


extension Pin {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Pin> {
        return NSFetchRequest<Pin>(entityName: "Pin")
    }

    @NSManaged public var title: String?
    @NSManaged public var isDownloading: Bool
    @NSManaged public var coordinate: Coordinate?
    @NSManaged public var flicks: NSOrderedSet?

}

// MARK: Generated accessors for flicks
extension Pin {

    @objc(insertObject:inFlicksAtIndex:)
    @NSManaged public func insertIntoFlicks(_ value: Flick, at idx: Int)

    @objc(removeObjectFromFlicksAtIndex:)
    @NSManaged public func removeFromFlicks(at idx: Int)

    @objc(insertFlicks:atIndexes:)
    @NSManaged public func insertIntoFlicks(_ values: [Flick], at indexes: NSIndexSet)

    @objc(removeFlicksAtIndexes:)
    @NSManaged public func removeFromFlicks(at indexes: NSIndexSet)

    @objc(replaceObjectInFlicksAtIndex:withObject:)
    @NSManaged public func replaceFlicks(at idx: Int, with value: Flick)

    @objc(replaceFlicksAtIndexes:withFlicks:)
    @NSManaged public func replaceFlicks(at indexes: NSIndexSet, with values: [Flick])

    @objc(addFlicksObject:)
    @NSManaged public func addToFlicks(_ value: Flick)

    @objc(removeFlicksObject:)
    @NSManaged public func removeFromFlicks(_ value: Flick)

    @objc(addFlicks:)
    @NSManaged public func addToFlicks(_ values: NSOrderedSet)

    @objc(removeFlicks:)
    @NSManaged public func removeFromFlicks(_ values: NSOrderedSet)

}
