//
//  Networking.swift
//  VirtualTourist
//
//  Created by Online Training on 6/16/17.
//  Copyright © 2017 Mitch Salcido. All rights reserved.
//
/*
 About Networking.swift:
 
 Code for networking-
 - create/run dataTask
 - Networking constants
 - enum for Error handling
 */

import Foundation

// errors
enum VTError: Swift.Error {
    case locationError(String)  // location error, CGCoding, etc
    case networkError(String)   // problems in URLSessionDataTask, networking errors
    case operatorError(String)  // issues such as typos, bad username/password, etc
    case generalError(String)   // misc/unknown error, etc
    case coreData(String)       // coreData related issue
}

enum NetworkingError: LocalizedError {
    case url(String)
    case response(String)
    case data(String)
}

struct Networking {
    
    // run a data task using parameters and completion
    func dataTaskForParameters(_ params: [String: AnyObject], completion: @escaping ([String:AnyObject]?, VTError?) -> Void) {
        
        /*
         Handle creation/running of dataTask
        */
        
        // test for good url
        guard let url = urlForParameters(params) else {
            completion(nil, VTError.networkError("Unable to create value URL"))
            return
        }
        
        // create request
        let request = URLRequest(url: url)
        
        // create request
        let task = URLSession.shared.dataTask(with: request) {
            (data, response, error) in
            
            // check error
            guard error == nil else {
                completion(nil, VTError.networkError("Error during data task"))
                return
            }
            
            // check status code in response..test for non 2xx
            guard let status = (response as? HTTPURLResponse)?.statusCode,
                status >= 200, status <= 299 else {
                    completion(nil, VTError.networkError("Bad status code returned: non 2xx"))
                    return
            }
            
            // check data
            guard let data = data else {
                completion(nil, VTError.networkError("Bad data returned from data task"))
                return
            }
            
            // convert data to json
            var jsonData: [String: AnyObject]!
            do {
                jsonData = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as! [String:AnyObject]
            } catch {
                completion(nil, VTError.networkError("Unable to convert returned data to usable format"))
                return
            }
            
            // good data. Fire completion using good data
            completion(jsonData, nil)
        }
        
        // fire task
        task.resume()
    }
    
    // create URL from parameters
    func urlForParameters(_ params: [String: AnyObject]) -> URL? {

        /*
         parse params and create/return url
        */
        
        // create components and add subcomponents
        var components = URLComponents()
        components.host = params[Networking.Keys.host] as? String
        components.scheme = params[Networking.Keys.scheme] as? String
        components.path = params[Networking.Keys.path] as! String
        
        // add queryItems
        let items = params[Networking.Keys.items] as! [String:String]
        var queryItems = [URLQueryItem]()
        for (key, value) in  items {
            let item = URLQueryItem(name: key, value: "\(value)")
            queryItems.append(item)
        }
        components.queryItems = queryItems
        
        return components.url
    }
}

extension Networking {
    
    // Constants keys for sifting out dictionaries in params passed into taskWithParams
    struct Keys {
        static let items = "items"
        static let host = "host"
        static let scheme = "scheme"
        static let path = "path"
    }
    
    // Constants values
    struct Values {
        static let secureScheme = "https"   // secure scheme
    }
}
