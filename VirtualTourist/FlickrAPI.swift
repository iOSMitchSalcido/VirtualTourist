//
//  FlickrAPI.swift
//  VirtualTourist
//
//  Created by Online Training on 6/16/17.
//  Copyright © 2017 Mitch Salcido. All rights reserved.
//
/*
 About FlickrAPI.swift:
 */

import Foundation
import CoreData

struct FlickrAPI {
    
    let SEARCH_RADIUS: Double = 10.0    // default search radius
    let MAX_IMAGES: Int = 100            // maximum number of images to download
    
    // search flicks for photos. Options for geography and text search
    func flickSearchforText(_ text: String? = nil,
                            geo: (lon: Double, lat: Double, radius: Double)? = nil,
                            completion: @escaping ([String: AnyObject]?, VTError?) -> Void) {
        
        // verify valid search params..
        guard (text != nil) || (geo != nil) else {
            completion(nil, VTError.operatorError("Invalid text or geo search items"))
            return
        }
        
        // base params..will ultimately be pulled as queryItems in url creation...
        var items = ["method": FlickrAPI.Methods.photosSearch,
                     FlickrAPI.Keys.apiKey: FlickrAPI.Values.apiKey,
                     FlickrAPI.Keys.format: FlickrAPI.Values.json,
                     FlickrAPI.Keys.extras: FlickrAPI.Values.mediumURL,
                     FlickrAPI.Keys.nojsoncallback: FlickrAPI.Values.nojsoncallback,
                     FlickrAPI.Keys.safeSearch: FlickrAPI.Values.safeSearch]
        
        // add text search
        if let text = text {
            items[FlickrAPI.Keys.text] = text
        }
        
        // add geo search
        if let geo = geo {
            items[FlickrAPI.Keys.longitude] = "\(geo.lon)"
            items[FlickrAPI.Keys.latitude] = "\(geo.lat)"
            items[FlickrAPI.Keys.radius] = "\(geo.radius)"
        }
        
        // params for task
        let params = [Networking.Keys.items: items,
                      Networking.Keys.host: FlickrAPI.Subcomponents.host,
                      Networking.Keys.scheme: FlickrAPI.Subcomponents.scheme,
                      Networking.Keys.path: FlickrAPI.Subcomponents.path] as [String : Any]
        
        // execute task
        let networking = Networking()
        networking.dataTaskForParameters(params as [String : AnyObject], completion: completion)
    }
    
    func createFlickrAlbumForPin(_ pin: Pin, withContainer container: NSPersistentContainer) {
        
        container.performBackgroundTask() { (privateContext) in
            privateContext.mergePolicy = NSMergePolicy.overwrite

            // Begin Flickr image search
            let lon = Double(pin.coordinate!.longitude)
            let lat = Double(pin.coordinate!.latitude)
            
            self.flickSearchforText(nil, geo: (lon, lat, self.SEARCH_RADIUS)) {
                (data, error) in
                
                guard let data = data else {
                    return
                }
                
                guard let photosDict = data["photos"] as? [String: AnyObject],
                    let photosArray = photosDict["photo"] as? [[String: AnyObject]] else {
                        return
                }
                
                // retieve url strings
                var urlStringArray = [String]()
                for dict in photosArray {
                    if let urlString = dict["url_m"] as? String,
                        urlStringArray.count < self.MAX_IMAGES {
                        urlStringArray.append(urlString)
                    }
                }
                
                let privatePin = privateContext.object(with: pin.objectID) as! Pin
                
                // create a Flick MO for each url string..add to Pin
                for string in urlStringArray {
                    let flick = Flick(context: privateContext)
                    flick.urlString = string
                    privatePin.addToFlicks(flick)
                }
                
                // Save
                do {
                    try privateContext.save()
                    print("urlStrings - good save")
                    
                    /*
                     Suspect Pin deleting issue is here..
                     When deleting Pin who's flicks are still being downloaded, sometimes get a bad save
                     ..some type of "collision" taking place in the way I'm performing background tasks
                     */
                    if let flicks = privatePin.flicks?.array as? [Flick] {
                        
                        for flick in flicks {
                            
                            if let urlString = flick.urlString,
                                let url = URL(string: urlString),
                                let data = NSData(contentsOf: url) {
                                
                                flick.image = data
                                do {
                                    try privateContext.save()
                                    print("\(String(describing: pin.title)) | imageData - good save")
                                } catch {
                                    print("\(String(describing: pin.title)) | imageData - unable to save private context")
                                }
                            }
                            else {
                                print("something nil in image data save")
                            }
                        }
                    }
                } catch {
                    print("urlStrings - unable to save private context")
                }
            }
        }
    }
    
    
    
    
    func createFlickrAlbumForAnnot(_ annot: VTAnnotation, withContainer container: NSPersistentContainer) {
        
        container.performBackgroundTask() { (privateContext) in
            privateContext.mergePolicy = NSMergePolicy.overwrite
            
            let pin = annot.pin!
            
            // Begin Flickr image search
            let lon = Double(pin.coordinate!.longitude)
            let lat = Double(pin.coordinate!.latitude)
            
            self.flickSearchforText(nil, geo: (lon, lat, self.SEARCH_RADIUS)) {
                (data, error) in
                
                guard let data = data else {
                    return
                }
                
                guard let photosDict = data["photos"] as? [String: AnyObject],
                    let photosArray = photosDict["photo"] as? [[String: AnyObject]] else {
                        return
                }
                
                // retieve url strings
                var urlStringArray = [String]()
                for dict in photosArray {
                    if let urlString = dict["url_m"] as? String,
                        urlStringArray.count < self.MAX_IMAGES {
                        urlStringArray.append(urlString)
                    }
                }
                
                let privatePin = privateContext.object(with: pin.objectID) as! Pin
                
                // create a Flick MO for each url string..add to Pin
                for string in urlStringArray {
                    
                    if annot.pin != nil {
                        let flick = Flick(context: privateContext)
                        flick.urlString = string
                        privatePin.addToFlicks(flick)
                    }
                }
                
                // Save
                do {
                    try privateContext.save()
                    print("urlStrings - good save")
                    
                    /*
                     Suspect Pin deleting issue is here..
                     When deleting Pin who's flicks are still being downloaded, sometimes get a bad save
                     ..some type of "collision" taking place in the way I'm performing background tasks
                     */
                    if let flicks = privatePin.flicks?.array as? [Flick] {
                        
                        for flick in flicks {
                            
                            if annot.pin != nil,
                                let urlString = flick.urlString,
                                let url = URL(string: urlString),
                                let data = NSData(contentsOf: url) {
                                
                                if annot.pin == nil {
                                    print("nil Pin")
                                }
                                
                                flick.image = data
                                do {
                                    try privateContext.save()
                                    print("\(String(describing: annot.pin?.title)) | imageData - good save")
                                } catch let error {
                                    print("\(String(describing: annot.pin?.title)) | imageData - unable to save private context")
                                    print(error.localizedDescription)
                                }
                            }
                            else {
                                print("something nil in image data save")
                            }
                        }
                    }
                } catch {
                    print("urlStrings - unable to save private context")
                }
            }
        }
    }
}

// constants
extension FlickrAPI {
    
    fileprivate struct Keys {
        
        // base params
        static let apiKey = "api_key"
        static let format = "format"
        static let extras = "extras"
        static let title = "title"
        static let nojsoncallback = "nojsoncallback"
        static let safeSearch = "safe_search"
        
        // search related params
        static let perPage = "per_page"
        static let page = "page"
        static let text = "text"
        static let longitude = "lon"
        static let latitude = "lat"
        static let radius = "radius"
    }
    
    fileprivate struct Values {
        
        // base params
        static let apiKey = "3bc85d1817c25bfd73b8a05ff26a01c3"
        static let json = "json"
        static let mediumURL = "url_m"
        static let nojsoncallback = "1"
        static let safeSearch = "1"
        static let title = "title"
        static let radius10K = "10"
    }
    
    // subcomponents used to form URL
    fileprivate struct Subcomponents {
        static let host = "api.flickr.com"
        static let path = "/services/rest"
        static let scheme = "https"
    }

    // methods
    fileprivate struct Methods {
        static let photosSearch = "flickr.photos.search"
    }
}
