//
//  VTAnnotation.swift
//  VirtualTourist
//
//  Created by Online Training on 6/17/17.
//  Copyright © 2017 Mitch Salcido. All rights reserved.
//
/*
 About VTAnnotation.swift
 
 Annotation subclass. Added Pin ref.
*/

import Foundation
import MapKit

class VTAnnotation: MKPointAnnotation {
    
    // ref to pin...need ref for deleting pinView
    var pin: Pin?
}
