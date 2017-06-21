//
//  CoreDataStack.swift
//  VirtualTourist
//
//  Created by Online Training on 6/17/17.
//  Copyright © 2017 Mitch Salcido. All rights reserved.
//

import Foundation
import CoreData

class CoreDataStack {
    
    let container: NSPersistentContainer
    
    init(_ modelName: String) {
        container = NSPersistentContainer(name: modelName)
        container.loadPersistentStores() {
            (description, error) in
            self.container.viewContext.automaticallyMergesChangesFromParent = true
        }
    }
    
    lazy var context: NSManagedObjectContext = {
        return self.container.viewContext
    } ()
}
