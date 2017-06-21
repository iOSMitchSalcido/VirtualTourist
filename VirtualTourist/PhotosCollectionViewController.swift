//
//  PhotosCollectionViewController.swift
//  VirtualTourist
//
//  Created by Online Training on 6/16/17.
//  Copyright © 2017 Mitch Salcido. All rights reserved.
//

import UIKit
import CoreData

class PhotosCollectionViewController: UICollectionViewController {

    // constant for spacing between cells
    let CELL_SPACING: CGFloat = 2.0
    
    // constant for number of cells in a row
    let CELLS_PER_ROW: CGFloat = 4.0

    var stack: CoreDataStack!
    var context: NSManagedObjectContext!
    var pin: Pin?
    
    @IBOutlet weak var flowLayout: UICollectionViewFlowLayout!
    
    var frc: NSFetchedResultsController<Pin>!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(privateContextNotification(_:)),
                                               name: NSNotification.Name.NSManagedObjectContextDidSave,
                                               object: nil)
        title = pin?.title
    }
    
    func privateContextNotification(_ notification: Notification) {
        
        NotificationCenter.default.removeObserver(self)
        DispatchQueue.main.async {
            print("PhotosCollectionViewController - privateContext")
            self.collectionView?.reloadData()
        }
    }
    
    // handle collectionView layout
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        
        // vertical scroll
        flowLayout.scrollDirection = .vertical

        // spacing between rows and cells
        flowLayout.minimumLineSpacing = CELL_SPACING
        flowLayout.minimumInteritemSpacing = CELL_SPACING

        // want five flicks/row..four gaps between cells means available space for cells is: screensWidth - 4 * CELL_SPACING
        let widthAvailableForCellsInRow = (collectionView?.frame.size.width)! - (CELLS_PER_ROW - 1.0) * CELL_SPACING
        flowLayout.itemSize = CGSize(width: widthAvailableForCellsInRow / CELLS_PER_ROW,
                                     height: widthAvailableForCellsInRow / CELLS_PER_ROW)
    }
}

// MARK: UICollectionViewDataSource
extension PhotosCollectionViewController {
    
    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        
        guard let count = pin?.flicks?.count else  {
            return 0
        }
        
        return count
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PhotosCVCellID", for: indexPath) as! PhotoCVCell
        
        guard let flick = pin?.flicks?.object(at: indexPath.row) as? Flick else {
            return cell
        }
        
        // Configure the cell
        cell.imageView.image = UIImage(named: "DefaultCVCellImage")
        cell.activityIndicator.isHidden = false
        cell.activityIndicator.startAnimating()
        
        if let image = flick.image as? UIImage {
            
            cell.activityIndicator.isHidden = true
            cell.activityIndicator.stopAnimating()
            cell.imageView.image = image
        }
        else if let urlString = flick.urlString,
            let url = URL(string: urlString) {
            
            cell.activityIndicator.isHidden = false
            cell.activityIndicator.startAnimating()
            
            let networking = Networking()
            networking.dataTaskForURL(url) {
                (data, error) in
                
                guard let imageData = data else {
                    return
                }
                
                let image = UIImage(data: imageData)
                
                DispatchQueue.main.async {
                    cell.imageView.image = image
                    cell.activityIndicator.stopAnimating()
                    cell.activityIndicator.isHidden = true
                }
                
                self.stack.container.performBackgroundTask() { (privateContext) in
                    
                    let privateFlick = privateContext.object(with: flick.objectID) as! Flick
                    privateFlick.image = image
                    
                    do {
                        try privateContext.save()
                    } catch {
                        print("unable to save private context")
                    }
                }
            }
        }

        return cell
    }
}

// MARK: UICollectionViewDelegate
extension PhotosCollectionViewController {
    /*
     // Uncomment this method to specify if the specified item should be highlighted during tracking
     override func collectionView(_ collectionView: UICollectionView, shouldHighlightItemAt indexPath: IndexPath) -> Bool {
     return true
     }
     */
    
    /*
     // Uncomment this method to specify if the specified item should be selected
     override func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
     return true
     }
     */
    
    /*
     // Uncomment these methods to specify if an action menu should be displayed for the specified item, and react to actions performed on the item
     override func collectionView(_ collectionView: UICollectionView, shouldShowMenuForItemAt indexPath: IndexPath) -> Bool {
     return false
     }
     
     override func collectionView(_ collectionView: UICollectionView, canPerformAction action: Selector, forItemAt indexPath: IndexPath, withSender sender: Any?) -> Bool {
     return false
     }
     
     override func collectionView(_ collectionView: UICollectionView, performAction action: Selector, forItemAt indexPath: IndexPath, withSender sender: Any?) {
     
     }
     */
}
