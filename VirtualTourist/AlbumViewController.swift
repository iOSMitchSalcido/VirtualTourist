//
//  AlbumViewController.swift
//  VirtualTourist
//
//  Created by Online Training on 6/16/17.
//  Copyright © 2017 Mitch Salcido. All rights reserved.
//

import UIKit
import CoreData

class AlbumViewController: UIViewController {
    
    // view objects
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    // cell presentation contants
    let CELL_SPACING: CGFloat = 2.0     // spacing between cells
    let CELLS_PER_ROW: CGFloat = 4.0    // number of cells per row, same for both portrait and landscape orientation

    // ref to stack, context, and Pin ..set in invoking VC
    var stack: CoreDataStack!
    var context: NSManagedObjectContext!
    
    // ref to Pin
    var pin: Pin!
    
    // progressView..indicate flick download progress
    var progressView: UIProgressView?
    
    // NSFetchedResultController
    var fetchedResultsController: NSFetchedResultsController<Flick>!
    
    // array of cell indexPaths for cell that are currently selected (checkmark, ready to delete)
    var selectedCellsIndexPaths = [IndexPath]()
    
    // layout
    @IBOutlet weak var flowLayout: UICollectionViewFlowLayout!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // view title
        title = pin.title
        
        // show toolbar
        navigationController?.setToolbarHidden(false, animated: false)
        
        activityIndicator.startAnimating()
        activityIndicator.isHidden = false
        
        // Core Data: Request, Sort/Predicate, and Controller
        let fetchRequest: NSFetchRequest<Flick> = Flick.fetchRequest()
        let sort = NSSortDescriptor(key: #keyPath(Flick.urlString), ascending: true)
        let predicate = NSPredicate(format: "pin == %@", pin!)
        fetchRequest.predicate = predicate
        fetchRequest.sortDescriptors = [sort]
        fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest,
                                                           managedObjectContext: context,
                                                           sectionNameKeyPath: nil,
                                                           cacheName: nil)
        fetchedResultsController.delegate = self
        
        // perform fetch
        do {
            try fetchedResultsController.performFetch()
            
            // test for download progress. 1.0 means all photos have already been downloaded...
            let progress = downloadProgress()
            if progress < 1.0 {
                
                // download not complete. Add progressView to toolbar to indicate status/progress
                // of downloading process
                progressView = UIProgressView(progressViewStyle: .default)
                progressView?.progress = progress
                let progBbi = UIBarButtonItem(customView: progressView!)
                let flexBbi = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
                setToolbarItems([flexBbi, progBbi, flexBbi], animated: false)
            }
            else {
                activityIndicator.stopAnimating()
                activityIndicator.isHidden = true
            }
        } catch {
            //TODO: error handling
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

        // create/set itemSize for cell
        let widthAvailableForCellsInRow = (collectionView?.frame.size.width)! - (CELLS_PER_ROW - 1.0) * CELL_SPACING
        flowLayout.itemSize = CGSize(width: widthAvailableForCellsInRow / CELLS_PER_ROW,
                                     height: widthAvailableForCellsInRow / CELLS_PER_ROW)
    }
}

// MARK: UICollectionViewDataSource
extension AlbumViewController: UICollectionViewDataSource {
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        
        guard let sections = fetchedResultsController.sections else {
            return 0
        }
        return sections.count
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        
        guard let section = fetchedResultsController.sections?[section] else {
            return 0
        }
        
        return section.numberOfObjects
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PhotoCellID", for: indexPath) as! PhotoCell
        
        // retieve flick
        let flick = fetchedResultsController.object(at: indexPath)
        
        // test if cell is selected for deletion
        cell.selectedImageView.isHidden = !selectedCellsIndexPaths.contains(indexPath)
        
        // test for valid image..has already been downloaded from Flickr
        if let imageData = flick.image {
            
            // valid imageData...place image in cell
            
            if let image = UIImage(data: imageData as Data) {
                cell.imageView.image = image
                cell.activityIndicator.isHidden = true
                cell.activityIndicator.stopAnimating()
            }
        }
        // imageData not finished downloading..use placeholder image w/activityView
        else if let urlString = flick.urlString,
            let url = URL(string: urlString) {
            
            cell.imageView.image = UIImage(named: "DefaultCVCellImage")
            cell.activityIndicator.isHidden = false
            cell.activityIndicator.startAnimating()
            
            let networking = Networking()
            networking.dataTaskForURL(url) { (data, error) in
                
                //TODO: error handling
                
                guard let data = data else {
                    return
                }
                
                flick.image = data as NSData
                
                do {
                    try self.context.save()
                } catch {
                    
                }
                
                DispatchQueue.main.async {
                    cell.imageView.image = UIImage(data: data)
                    cell.activityIndicator.isHidden = true
                    cell.activityIndicator.stopAnimating()
                }
            }
        }

        return cell
    }
}

extension AlbumViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    }
}

extension AlbumViewController: NSFetchedResultsControllerDelegate {
    
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        
        switch type {
        case .insert:
            print("didChange -insert , count: \(String(describing: controller.fetchedObjects?.count))")
        case .delete:
            collectionView.reloadData()
            print("didChange -delete , count: \(String(describing: controller.fetchedObjects?.count))")
        case .move:
            print("didChange -move , count: \(String(describing: controller.fetchedObjects?.count))")
        case .update:
            print("didChange -update , count: \(String(describing: controller.fetchedObjects?.count))")
            collectionView.reloadItems(at: [indexPath!])
        }
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        print("didChangeContent , count: \(String(describing: controller.fetchedObjects?.count))")
        
        /*
         Handle UI while downloading/editing is happening. Test download progress, set UI elements
         to indicate status of downloading
        */
        
        // retrieve download progress
        let progress = downloadProgress()
        
        // progress has started.. remove activity indicator which is in center of screen..cells are now beginning
        // to load. Cells with nil image have placeholder image..
        if progress > 0.0 {
            activityIndicator.stopAnimating()
            activityIndicator.isHidden = true
        }
        
        // update progressView
        if let progressView = progressView {
            if progress < 1.0 {
                progressView.setProgress(progress, animated: true)
            }
            else {
                // done downloading (progress >= 1.0)
                setToolbarItems(nil, animated: true)
                self.progressView = nil
            }
        }
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange sectionInfo: NSFetchedResultsSectionInfo, atSectionIndex sectionIndex: Int, for type: NSFetchedResultsChangeType) {
    }
}

// helper functions
extension AlbumViewController {
    
    // return download progress
    func downloadProgress() -> Float {
        
        // verify valid objects
        guard let fetchedObjects = fetchedResultsController.fetchedObjects else {
            return 0.0
        }
        
        // get count, test for zero objects and return 0.0
        let count = Float(fetchedObjects.count)
        if count == 0.0 {
            return 0.0
        }
        
        // count non-nil image, sum
        var downloadCount: Float = 0.0
        for flick in fetchedResultsController.fetchedObjects! {
            if flick.image != nil {
                downloadCount = downloadCount + 1.0
            }
        }
        
        // return ratio
        return downloadCount / count
    }
}
