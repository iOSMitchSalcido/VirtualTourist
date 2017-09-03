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

struct Networking {
    
    // run a data task using parameters and completion
    func dataTaskForParameters(_ params: [String: AnyObject], completion: @escaping ([String:AnyObject]?, LocalizedError?) -> Void) {
        
        /*
         Handle creation/running of dataTask
        */
        
        // test for good url
        guard let url = urlForParameters(params) else {
            completion(nil, NetworkingError.url("Unusable or missing URL."))
            return
        }
        
        // create request
        let request = URLRequest(url: url)
        
        // create request
        let task = URLSession.shared.dataTask(with: request) {
            (data, response, error) in
            
            // check error
            guard error == nil else {
                completion(nil, NetworkingError.task)
                return
            }
            
            // check status code in response..test for non 2xx
            guard let status = (response as? HTTPURLResponse)?.statusCode,
                status >= 200, status <= 299 else {
                    if let status = (response as? HTTPURLResponse)?.statusCode {
                        completion(nil, NetworkingError.response(status))
                    }
                    else {
                        completion(nil, NetworkingError.response(nil))
                    }
                    return
            }

            // check data
            guard let data = data else {
                completion(nil, NetworkingError.data("Bad or missing data returned."))
                return
            }

            // convert data to json
            var jsonData: [String: AnyObject]!
            do {
                jsonData = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as! [String:AnyObject]
            } catch {
                completion(nil, NetworkingError.data("Unable to convert returned network data to usable JSON format."))
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

// error handling
extension Networking {
    
    // network error handling
    enum NetworkingError: LocalizedError {
        case url(String)
        case data(String)
        case response(Int?)
        case task
        
        // description: For use in Alert Title
        var errorDescription: String? {
            get {
                switch self {
                case .url:
                    return "Network Error: URL"
                case .data:
                    return "Network Error: Data"
                case .response:
                    return "Newtork Error: Response"
                case .task:
                    return "Newtork Error: Task"
                }
            }
        }
        
        // reason: For use in Alert Message
        var failureReason: String? {
            get {
                switch self {
                case .url(let value):
                    return value
                case .data(let value):
                    return value
                case .response(let value):
                    if let value = value {
                        return "Bad response code returned: \(value)"
                    }
                    return "Bad response. No status code returned"
                case .task:
                    return "Network task error encountered"
                }
            }
        }
    }
}

// constants
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
