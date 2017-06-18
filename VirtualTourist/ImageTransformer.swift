//
//  ImageTransformer.swift
//  VirtualTourist
//
//  Created by Online Training on 6/18/17.
//  Copyright © 2017 Mitch Salcido. All rights reserved.
//

import Foundation
import UIKit

class ImageTransformer: ValueTransformer {
    
    override class func transformedValueClass() -> AnyClass {
        return NSData.self
    }
    
    override class func allowsReverseTransformation() -> Bool {
        return true
    }
    
    override func transformedValue(_ value: Any?) -> Any? {
        
        guard let image = value as? UIImage else {
            return nil
        }
        return UIImagePNGRepresentation(image)
    }
    
    override func reverseTransformedValue(_ value: Any?) -> Any? {
        
        guard let data = value as? Data else {
            return nil
        }
        
        return UIImage(data: data)
    }
}
