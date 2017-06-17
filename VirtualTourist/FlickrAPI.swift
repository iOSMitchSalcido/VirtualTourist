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

struct FlickrAPI {
    
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
}

// constants
extension FlickrAPI {
    
    fileprivate struct Keys {
        
        // base params
        static let apiKey = "api_key"
        static let format = "format"
        static let extras = "extras"
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
        
        // radius search accuracy
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
