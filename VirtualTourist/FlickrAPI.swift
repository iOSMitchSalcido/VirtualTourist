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
import MapKit

struct FlickrAPI {
    
    let SEARCH_RADIUS: Double = 10.0    // default search radius
    let MAX_IMAGES: Int = 50            // maximum number of images to download
    
    // create a flickr album
    func createFlickrAlbumForPin(_ pin: Pin,
                                 completion: @escaping ([String]?, VTError?) -> Void) {
        
        /*
         Info:
         This method begins the invocation of a flickr search. The search is a Flickr geo search. The
         geo info is extracted from the Pin (coordinate attrib).
         
         The completion block receives a string array which contains the URL's, in string format, of the
         found flicks, otherwise a VTError
         */
        
        // verify good coordinates
        guard let longitude = pin.coordinate?.longitude,
            let latitude = pin.coordinate?.latitude else {
                completion(nil, VTError.operatorError("Bad Pin/Location"))
                return
        }
        
        // create a CLLocationCoord and invoke search
        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        self.flicksSearchInCoordinate(coordinate) {
            (data, error) in
            
            // test error
            guard error == nil else {
                completion(nil, VTError.locationError("Error search for flicks"))
                return
            }
            
            // test data
            guard let data = data else {
                completion(nil, VTError.networkError("Bad data returned from Flickr"))
                return
            }
            
            // retrieve Flickr data
            guard let photosDict = data[FlickrAPI.Keys.photosDictionary] as? [String: AnyObject],
                let photosArray = photosDict[FlickrAPI.Keys.photosArray] as? [[String: AnyObject]] else {
                    completion(nil, VTError.networkError("Unable to retrieve Flickr data"))
                    return
            }
            
            // photos array now contains found flicks as an array of dictionaries
            
            // retrieve URL as strings...stay under max count
            var urlStrings = [String]()
            for photos in photosArray {
                if let urlString = photos[FlickrAPI.Values.mediumURL] as? String,
                    urlStrings.count < self.MAX_IMAGES {
                    urlStrings.append(urlString)
                }
            }
            
            // fire completion with array
            completion(urlStrings, nil)
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

extension FlickrAPI {
    
    // search Flickr for flicks based on geo
    fileprivate func flicksSearchInCoordinate(_ coordinate: CLLocationCoordinate2D,
                                  completion: @escaping ([String: AnyObject]?, VTError?) -> Void) {
        
        /*
         Info:
         Perform a Flickr geo search.
        */
        
        // base params..will ultimately be pulled as queryItems in url creation...
        var items = ["method": FlickrAPI.Methods.photosSearch,
                     FlickrAPI.Keys.apiKey: FlickrAPI.Values.apiKey,
                     FlickrAPI.Keys.format: FlickrAPI.Values.json,
                     FlickrAPI.Keys.extras: FlickrAPI.Values.mediumURL,
                     FlickrAPI.Keys.nojsoncallback: FlickrAPI.Values.nojsoncallback,
                     FlickrAPI.Keys.safeSearch: FlickrAPI.Values.safeSearch]
        
        // params for geo search
        items[FlickrAPI.Keys.longitude] = "\(coordinate.longitude)"
        items[FlickrAPI.Keys.latitude] = "\(coordinate.latitude)"
        items[FlickrAPI.Keys.radius] = "\(self.SEARCH_RADIUS)"
        
        // params for task
        let params = [Networking.Keys.items: items,
                      Networking.Keys.host: FlickrAPI.Subcomponents.host,
                      Networking.Keys.scheme: FlickrAPI.Subcomponents.scheme,
                      Networking.Keys.path: FlickrAPI.Subcomponents.path] as [String : Any]
        
        // execute task
        let networking = Networking()
        networking.dataTaskForParameters(params as [String : AnyObject], completion: completion)
    }
}
