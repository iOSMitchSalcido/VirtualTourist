//
//  ViewController+Extensions.swift
//  VirtualTourist
//
//  Created by Online Training on 6/14/17.
//  Copyright © 2017 Mitch Salcido. All rights reserved.
//
/*
 About ViewController+Extensions.swift:
 */

import UIKit
import CoreData

// alerts
extension UIViewController {
    
    // procced/cancel alert
    func presentProceedCancelAlert(title: String? = nil, message: String? = nil, completion: ((UIAlertAction) -> Void)?) {
       
        /*
         Alert controller: Create and present an alert with a "Procced" button and a "Cancel" button.
         Pressing the Proceed with fire the completion.
        */
        
        let alert = UIAlertController(title: title,
                                      message: message,
                                      preferredStyle: .alert)
        
        let proceedAction = UIAlertAction(title: "Proceed", style: .destructive, handler: completion)
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        alert.addAction(cancelAction)
        alert.addAction(proceedAction)
        present(alert, animated: true)
    }
    
    // cancel alert
    func presentCancelAlert(title: String, message: String? = nil, completion: ((UIAlertAction) -> Void)?) {
        
        /*
         Alert controller: Create and present an alert with "Cancel" button.
         Pressing Cancel will fire the completion.
         */
        
        let alert = UIAlertController(title: title,
                                      message: message,
                                      preferredStyle: .alert)
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: completion)
        alert.addAction(cancelAction)
        present(alert, animated: true)
    }
    
    // Alert for error handling
    func presentAlertForError(_ error: VTError) {
        
        /*
         Alert controller: Create and present an alert with "OK" button..used to provide user feedback for error
         */
        
        var alertTitle: String!
        var alertMessage: String!
        switch error {
        case .locationError(let value):
            alertTitle = "Location Error"
            alertMessage = value
        case .generalError(let value):
            alertTitle = "General Error"
            alertMessage = value
        case .networkError(let value):
            alertTitle = "Network Error"
            alertMessage = value
        case .operatorError(let value):
            alertTitle = "Operator Error"
            alertMessage = value
        case .coreData(let value):
            alertTitle = "Core Data Error"
            alertMessage = value
        }
        
        let alert = UIAlertController(title: alertTitle, message: alertMessage, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// related to core data and Flick downloading
extension UIViewController {
    
    // download album of flicks for a Pin
    func downloadAlbumForPin(_ pin: Pin, stack: CoreDataStack) {
        
        // perform on private context/queue
        let privateContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        privateContext.parent = stack.context
        privateContext.perform {
            
            print("downloadAlbumForPin - privateQueueu")
            
            // retrieve pin. Indicate downloading
            let pin = privateContext.object(with: pin.objectID) as! Pin
            let flicks = pin.flicks
            pin.isDownloading = true
            
            // delete all flicks
            for flick in flicks! {
                privateContext.delete(flick as! NSManagedObject)
            }
            
            // save..capture flick deletion and isDownloading set to false
            do {
                try privateContext.save()
                
                stack.context.performAndWait {
                    do {
                        try stack.context.save()
                    } catch let error {
                        print("error: \(error.localizedDescription)")
                        return
                    }
                }
            } catch let error {
                print("error: \(error.localizedDescription)")
                return
            }
            
            // begin download of new album using API call
            FlickrAPI().createFlickrAlbumForPin(pin, page: nil) {
                (data, error) in
                
                // test error, show alert if error
                guard error == nil else {
                    DispatchQueue.main.async {
                        self.presentAlertForError(error!)
                    }
                    return
                }
                
                // test data, show alert if bad data
                guard let data = data else {
                    DispatchQueue.main.async {
                        self.presentAlertForError(VTError.networkError("Bad data returned from Flickr."))
                    }
                    return
                }
                
                // create flicks..assign urlString
                for urlString in data {
                    let flick = Flick(context: privateContext)
                    flick.urlString = urlString
                    pin.addToFlicks(flick)
                }
                
                // save...will cause frc to repopulate cv with default image
                do {
                    try privateContext.save()
                    
                    stack.context.performAndWait {
                        do {
                            try stack.context.save()
                        } catch let error {
                            print("error: \(error.localizedDescription)")
                            return
                        }
                    }
                } catch let error {
                    print("error: \(error.localizedDescription)")
                    return
                }
                
                /*
                 Now pull image data..
                 Want to sort by urlString to match ordering used in FetchResultController
                 in AlbumVC..for aesthetic reasons..forces images to load in AlbumVC cells
                 in the order of the cells (top to bottom of collectionView)
                 */
                
                // request
                let request: NSFetchRequest<Flick> = Flick.fetchRequest()
                let sort = NSSortDescriptor(key: #keyPath(Flick.urlString), ascending: true)
                let predicate = NSPredicate(format: "pin == %@", pin)
                request.predicate = predicate
                request.sortDescriptors = [sort]
                do {
                    
                    // perform fetch
                    let flicks = try privateContext.fetch(request)
                    
                    // iterate, pull image data and assign to Flick
                    // ..save as each flick is retrieved
                    for flick in flicks {
                        
                        // verify good url, data
                        if let urlString = flick.urlString,
                            let url = URL(string: urlString),
                            let imageData = NSData(contentsOf: url) {
                            
                            // assign data to Flick
                            flick.image = imageData
                            
                            // save
                            do {
                                try privateContext.save()
                                
                                stack.context.performAndWait {
                                    do {
                                        try stack.context.save()
                                    } catch let error {
                                        print("error: \(error.localizedDescription)")
                                        return
                                    }
                                }
                            } catch let error {
                                print("error: \(error.localizedDescription)")
                                return
                            }
                        }
                    }
                    
                    // done downloading
                    pin.isDownloading = false
                    // save....capture setting download to false
                    do {
                        try privateContext.save()
                        
                        stack.context.performAndWait {
                            do {
                                try stack.context.save()
                            } catch let error {
                                print("error: \(error.localizedDescription)")
                                return
                            }
                        }
                    } catch let error {
                        print("error: \(error.localizedDescription)")
                        return
                    }
                } catch {
                    print("error: \(error.localizedDescription)")
                    return
                }
            }
        }
    }
    
    func resumeAlbumDownloadForPin(_ pin: Pin, stack: CoreDataStack) {
        
        /*
         finish downloading flicks for a Pin that has flicks with nil image data
         ..this condition might occur if app was terminated during a download, leaving
         flicks with nil image data that still needs download.
         */
        
        // perform on private context/queue
        let privateContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        privateContext.parent = stack.context
        privateContext.perform {
            
            print("resumeAlbumDownloadForPin - privateQueue")
            
            // retrieve pin, set isDownloading
            let pin = privateContext.object(with: pin.objectID) as! Pin
            pin.isDownloading = true
            
            // request
            let request: NSFetchRequest<Flick> = Flick.fetchRequest()
            let sort = NSSortDescriptor(key: #keyPath(Flick.urlString), ascending: true)
            let predicate = NSPredicate(format: "pin == %@", pin)
            request.predicate = predicate
            request.sortDescriptors = [sort]
            
            // perform fetch
            do {
                let flicks = try privateContext.fetch(request)
                
                // iterate, retrieve image data
                for flick in flicks {
                    
                    if flick.image == nil,
                        let urlString = flick.urlString,
                        let url = URL(string: urlString),
                        let imageData = NSData(contentsOf: url) {
                        
                        flick.image = imageData
                        
                        // save
                        do {
                            try privateContext.save()
                            
                            stack.context.performAndWait {
                                do {
                                    try stack.context.save()
                                } catch let error {
                                    print("error: \(error.localizedDescription)")
                                    return
                                }
                            }
                        } catch let error {
                            print("error: \(error.localizedDescription)")
                            return
                        }
                    }
                }
                // done downloading
                pin.isDownloading = false
                
                // save
                do {
                    try privateContext.save()
                    
                    stack.context.performAndWait {
                        do {
                            try stack.context.save()
                        } catch let error {
                            print("error: \(error.localizedDescription)")
                            return
                        }
                    }
                } catch let error {
                    print("error: \(error.localizedDescription)")
                    return
                }
            } catch {
                print("error: \(error.localizedDescription)")
                return
            }
        }
    }
}
