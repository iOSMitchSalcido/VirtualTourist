//
//  PhotoCVCell.swift
//  VirtualTourist
//
//  Created by Online Training on 6/17/17.
//  Copyright © 2017 Mitch Salcido. All rights reserved.
//
/*
 About PhotoCVCell.swift
 
 CV cell subclass. Add ref's for:
 - cell imageView (for displayin flick in cell)
 - activityIndicator to indicate download activity for cell/flick
 - selectedImageView, "checkmark" image to indicate that cell/flick has been selected for deletion
 */

import UIKit

class PhotoCell: UICollectionViewCell {
    
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var selectedImageView: UIImageView!
}
