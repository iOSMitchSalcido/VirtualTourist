//
//  Networking.swift
//  VirtualTourist
//
//  Created by Online Training on 6/16/17.
//  Copyright © 2017 Mitch Salcido. All rights reserved.
//

import Foundation

// errors
enum VTError: Swift.Error {
    
    case locationError(String)  // location error, CGCoding, etc
    case networkError(String)   // problems in URLSessionDataTask, networking errors
    case operatorError(String)  // issues such as typos, bad username/password, etc
    case generalError(String)   // misc/unknown error, etc
}
