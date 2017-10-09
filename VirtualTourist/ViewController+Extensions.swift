//
//  ViewController+Extensions.swift
//  VirtualTourist
//
//  Created by Online Training on 6/14/17.
//  Copyright © 2017 Mitch Salcido. All rights reserved.
//
/*
 About ViewController+Extensions.swift:
 
 functions for use in UIViewController subclasses.
 
 - Alert/Action Controllers
 - Flick/Album dowloading
 */

import UIKit
import CoreData

// dismiss VC & common bbi functions
extension UIViewController {
    
    // for dismissing VC when a done bbi pressed
    @IBAction func doneBbiPresses(_ bbi: UIBarButtonItem) {
        dismiss(animated: true, completion: nil);
    }
}

// enums for error: CoreData and location
extension UIViewController {
    
    // Core data errors
    enum CoreDataError: LocalizedError {
        case fetch(String)
        case save(String)
        case data(String)
        
        // description: For use in Alert Title
        var errorDescription: String? {
            get {
                switch self {
                case .fetch:
                    return "CoreData Error: Fetch"
                case .save:
                    return "CoreData Error: Save"
                case .data:
                    return "CoreData Error: Data"
                }
            }
        }
        
        // reason: For use in Alert Message
        var failureReason: String? {
            get {
                switch self {
                case .fetch(let value):
                    return value
                case .save(let value):
                    return value
                case .data(let value):
                    return value
                }
            }
        }
    }
    
    // Core data errors
    enum LocationError: LocalizedError {
        case location(String)
        case status(String)
        
        // description: For use in Alert Title
        var errorDescription: String? {
            get {
                switch self {
                case .location:
                    return "Location Error: Location"
                case .status:
                    return "Location Error: Status"
                }
            }
        }
        
        // reason: For use in Alert Message
        var failureReason: String? {
            get {
                switch self {
                case .location(let value):
                    return value
                case .status(let value):
                    return value
                }
            }
        }
    }
}

// alerts
extension UIViewController {
    
    // Alert for error handling
    func presentAlertForLocalizedError(_ error: LocalizedError) {
        
        /*
         Alert controller: Create and present an alert with "OK" button..used to provide user feedback for error
         */
        
        var alertTitle = "Unknown Error"
        var alertMessage = "Please close app and then re-start"
        
        if let title = error.errorDescription {
            alertTitle = title
        }
        
        if let message = error.failureReason {
            alertMessage = message
        }
        
        let alert = UIAlertController(title: alertTitle, message: alertMessage, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
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
}

// related to core data and Flick downloading
extension UIViewController {
    
    // download album of flicks for a Pin
    func downloadAlbumForPin(_ pin: Pin, stack: CoreDataStack) {
        
        /*
         Handle downloading of Flickr photos into a Pin.
         Each flick received is assigned to a Flick MO which is attached to Pin
         */
        
        // test for valid coordinate data
        guard let latitude = pin.coordinate?.latitude,
            let longitude = pin.coordinate?.longitude else {
                presentAlertForLocalizedError(LocationError.location("Bad location data for Pin"))
                return
        }
        
        // set to downloading state
        pin.isDownloading = true
        
        // begin download of new album using API call
        let coordinate = FlickrCoordinate(latitude: latitude, longitude: longitude)
        FlickrAPI.shared.createFlickrAlbumForCoordinate(coordinate, page: nil) {
            (data, error) in
            
            // receive/parse data, perform on private queue/context
            let privateContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
            privateContext.parent = stack.context
            privateContext.perform {
                
                // pull pin ref into private context
                let pin = privateContext.object(with: pin.objectID) as! Pin
                
                // test error, data
                guard error == nil,
                    let data = data else {
                    
                        pin.isDownloading = false
                        let _ = stack.savePrivateContext(privateContext)
                        return
                }

                // test for no data returned
                if data.isEmpty {
                    
                    pin.noFlicksAtLocation = true
                    pin.isDownloading = false
                    let _ = stack.savePrivateContext(privateContext)
                    return
                }

                /*
                 Flickr data and flick creation is performed in two passes. The first pass is to simply retrieve
                 the urlString array returned from API call (data) and then create Flick MO's using urlString.
                 Upon saving, this will trigger an FRC attached to Pin to reload a collectionView with placehold
                 default images.
                 
                 Second pass is to perform actual download of images from Flickr and assign to Flick.
                 
                 ..for aesthetic purposes, to give the user immediate feedback on the flicks that
                 are to populate a collectionView.
                 */

                // create flicks, assign urlString, add to pin
                // ..use same sort order as used in frc in AlbumVC frc
                let urlStrings = data.sorted(by: { $0 < $1 })
                var flicks = [Flick]()
                for urlString in urlStrings {
                 
                    // only create a flick if a valid url
                    if let _ = URL(string: urlString) {
                        let flick = Flick(context: privateContext)
                        flick.urlString = urlString
                        pin.addToFlicks(flick)
                        flicks.append(flick)
                    }
                }

                // save...will cause frc to repopulate cv with default image
                if (!stack.savePrivateContext(privateContext)) {
                    return
                }

                // iterate, download imageData, save on each download
                for flick in flicks {
                    
                    if let urlString = flick.urlString,
                        let url = URL(string: urlString),
                        let imageData = NSData(contentsOf: url) {
                        flick.image = imageData
                        let _ = stack.savePrivateContext(privateContext)
                    }
                }
                
                // done downloading
                pin.isDownloading = false
                
                // save....capture setting download to false
                let _ = stack.savePrivateContext(privateContext)
            }
        }
    }
    
    // resume download
    func resumeAlbumDownloadForPin(_ pin: Pin, stack: CoreDataStack) {
        
        /*
         finish downloading flicks for a Pin that has flicks with nil image data
         ..this condition might occur if app was terminated during a download, leaving
         flicks with nil image data that still needs download.
         */
        
        // set download state
        pin.isDownloading = true

        // perform on private context/queue
        let privateContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        privateContext.parent = stack.context
        privateContext.perform {
            
            /*
             171008 bug fix
             Intermittent: On app launch, crash if Pin was deleted when download was in progress
             Caused by reading flick that was deleted.
             Update to test Pin/Flick before beginning download of image data
            */
            // verify good pin and flicks
            guard let pin = privateContext.object(with: pin.objectID) as? Pin,
                let flicks = pin.flicks else {
                    return
            }
            
            // iterate
            for flick in flicks {
                
                // verify good flick, urlString, URL before retrieving imageData
                if let flick = flick as? Flick,
                    let urlString = flick.urlString,
                    let url = URL(string: urlString),
                    let imageData = NSData(contentsOf: url) {
                    
                    // good imageData
                    flick.image = imageData
                    let _ = stack.savePrivateContext(privateContext)
                }
                else {
                    
                    // bad..possible Pin deletion during downloading of flicks
                    return
                }
            }
            
            // done downloading
            pin.isDownloading = false
            
            // save....capture setting download to false
            let _ = stack.savePrivateContext(privateContext)
        }
    }
}
