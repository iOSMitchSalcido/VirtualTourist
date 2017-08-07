//
//  FlickrAPI.swift
//  VirtualTourist
//
//  Created by Online Training on 6/16/17.
//  Copyright © 2017 Mitch Salcido. All rights reserved.
//
/*
 About FlickrAPI.swift:
 
 Interface for downloading flicks from Flickr
 */

import Foundation

// struct for coordinate
struct FlickrCoordinate {
    let latitude: Double
    let longitude: Double
}

struct FlickrAPI {
    
    // constants
    let searchRadius: Double = 10.0                     // default search radius
    let maximumImageDownloadCount: Int = 50             // maximum number of images to download
    let maxFlicksReturnedByFlickr: Int = 4000           // maximum number of flicks that Flickr will return
    
    // create a flickr album
    func createFlickrAlbumForCoordinate(_ coordinate: FlickrCoordinate,
                                 page: Int?,
                                 completion: @escaping ([String]?, VTError?) -> Void) {
        /*
         Handle downloading an "album" of flicks from flickr. Pin is passed as an argument to pull location info
         for flickr search.
         
         Arguments passed into function:
         - coordinate, FlickrCoordinate as defined above
         - page, !! page must be nil !! ..this argument is used recursively on a second call to this function below
         
         
         Completion:
         - [String]?, Array of urls in string format. Array contains url's of flicks found during search
         - VTError?, error enum defined in file Networking
         */
        
        // invoke search
        let params = createPhotoSearchParamsForCoordinate(coordinate, page: page)
        
        // network task
        Networking().dataTaskForParameters(params) {
            (data, error) in
            
            // test error
            guard error == nil else {
                completion(nil, VTError.networkError("Error search for flicks"))
                return
            }
            
            // test data
            guard let data = data else {
                completion(nil, VTError.networkError("Bad data returned from Flickr"))
                return
            }
            
            /*
             Flickr search is performed in two passes. The first pass, with page = nil, the returned
             flickr data is parsed for number of pages. A random page is determined and then this function
             is invoked once again, only this time with page = randomPage
             */
            
            // retrieve Flickr data
            guard let photosDict = data[FlickrAPI.Keys.photosDictionary] as? [String: AnyObject],
                let items = params[Networking.Keys.items] as? [String: AnyObject] else {
                    completion(nil, VTError.networkError("Unable to retrieve Flickr data"))
                    return
            }
            
            // test if page was a search param
            if items[FlickrAPI.Keys.page] == nil {
                
                /*
                 page NOT a search param. Retrieve number of available pages, get a random page
                 and perform a new search
                 */
                
                // get page info
                guard let pages = photosDict[FlickrAPI.Keys.pages] as? Int,
                    let perPage = photosDict[FlickrAPI.Keys.perPage] as? Int else {
                        completion(nil, VTError.networkError("Unable to retrieve Flickr data"))
                        return
                }
                
                // Flickr has photo limit. Get max allowable page search, generate a random page
                let pageLimit = min(pages, self.maxFlicksReturnedByFlickr / perPage)
                let randomPage = Int(arc4random_uniform(UInt32(pageLimit))) + 1
                
                // run new search using random page
                self.createFlickrAlbumForCoordinate(coordinate, page: randomPage, completion: completion)
            }
            else {
                
                /*
                 page was a search param.
                 retrieve url strings from search...fire completion
                 */
                
                // page was a search param..proceed to retrieve flick URL's as strings
                guard let photosArray = photosDict[FlickrAPI.Keys.photosArray] as? [[String: AnyObject]] else {
                    completion(nil, VTError.networkError("Unable to retrieve Flickr data"))
                    return
                }
                
                // retrieve URL as strings...stay under max count
                var urlStrings = [String]()
                for photos in photosArray {
                    if let urlString = photos[FlickrAPI.Values.mediumURL] as? String,
                        urlStrings.count < self.maximumImageDownloadCount {
                        urlStrings.append(urlString)
                    }
                }
                
                // fire completion with array
                completion(urlStrings, nil)
            }
        }
    }
    
    // helper function to create params used by data task for flick search
    func createPhotoSearchParamsForCoordinate(_ coordinate: FlickrCoordinate, page: Int?) -> [String: AnyObject] {
        
        /*
         Build params for network task using location, page, and constants defined below...
        */
        
        // build base params
        var items = ["method": FlickrAPI.Methods.photosSearch,
                     FlickrAPI.Keys.apiKey: FlickrAPI.Values.apiKey,
                     FlickrAPI.Keys.format: FlickrAPI.Values.json,
                     FlickrAPI.Keys.extras: FlickrAPI.Values.mediumURL,
                     FlickrAPI.Keys.nojsoncallback: FlickrAPI.Values.nojsoncallback,
                     FlickrAPI.Keys.safeSearch: FlickrAPI.Values.safeSearch,
                     FlickrAPI.Keys.longitude: "\(coordinate.longitude)",
            FlickrAPI.Keys.latitude: "\(coordinate.latitude)",
            FlickrAPI.Keys.radius: "\(self.searchRadius)"]
        
        // include page search if non-nil
        if let page = page {
            items["page"] = "\(page)"
        }
        
        // return params for task
        return [Networking.Keys.items: items as AnyObject,
                Networking.Keys.host: FlickrAPI.Subcomponents.host as AnyObject,
                Networking.Keys.scheme: FlickrAPI.Subcomponents.scheme as AnyObject,
                Networking.Keys.path: FlickrAPI.Subcomponents.path as AnyObject]
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
        static let perPage = "perpage"
        static let page = "page"
        static let pages = "pages"
        static let total = "total"
        static let text = "text"
        static let longitude = "lon"
        static let latitude = "lat"
        static let radius = "radius"
        
        // keys to returned data
        static let photosDictionary = "photos"
        static let photosArray = "photo"
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
