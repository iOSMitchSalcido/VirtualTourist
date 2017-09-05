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
            
            // !! inconsistant Pin deletion unless merge policy is set
            self.container.viewContext.mergePolicy = NSMergePolicy.overwrite
        }
    }
    
    lazy var context: NSManagedObjectContext = {
        return self.container.viewContext
    } ()
    
    // function to save a privateContext
    func savePrivateContext(_ privateContext: NSManagedObjectContext) -> Bool {
        
        /*
         Save private context
         Save view context
         */
        
        var success = true
        
        do {
            try privateContext.save()
            
            self.context.performAndWait {
                do {
                    try self.context.save()
                } catch {
                    success = false
                }
            }
        } catch {
            success = false
        }
        
        return success
    }
}
