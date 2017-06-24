//
//  AlbumCollectionViewController.swift
//  VirtualTourist
//
//  Created by Online Training on 6/16/17.
//  Copyright © 2017 Mitch Salcido. All rights reserved.
//

import UIKit
import CoreData

class AlbumCollectionViewController: UIViewController {

    @IBOutlet weak var collectionView: UICollectionView!
    
    // cell presentation contants
    let CELL_SPACING: CGFloat = 2.0     // spacing between cells
    let CELLS_PER_ROW: CGFloat = 4.0    // number of cells per row

    // ref to stack, context, and Pin ..set in invoking VC
    var stack: CoreDataStack!
    var context: NSManagedObjectContext!
    
    // ref to Pin
    var pin: Pin!
    
    // NSFetchedResultController
    var fetchedResultsController: NSFetchedResultsController<Flick>!
    
    // layout
    @IBOutlet weak var flowLayout: UICollectionViewFlowLayout!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = pin.title

        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .refresh,
                                                            target: self,
                                                            action: #selector(testBbiPressed(_:)))
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(contextNotification(_:)),
                                               name: Notification.Name.NSManagedObjectContextDidSave,
                                               object: nil)
        
        let fetchRequest: NSFetchRequest<Flick> = Flick.fetchRequest()
        let sort = NSSortDescriptor(key: #keyPath(Flick.urlString), ascending: true)
        let predicate = NSPredicate(format: "pin == %@", pin!)
        fetchRequest.predicate = predicate
        fetchRequest.sortDescriptors = [sort]
        
        fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest,
                                                           managedObjectContext: context,
                                                           sectionNameKeyPath: nil,
                                                           cacheName: nil)
        
        do {
            try fetchedResultsController.performFetch()
            if let count = fetchedResultsController.fetchedObjects?.count, count > 0 {
                print("count: \(count)")
                fetchedResultsController.delegate = self
            }
        } catch {
            
        }
    }
    
    func testBbiPressed(_ sender: UIBarButtonItem) {
        print("testBbiPressed")
    }
    
    func contextNotification(_ notification: Notification) {
        
        NotificationCenter.default.removeObserver(self)

        do {
            try fetchedResultsController.performFetch()
            if let count = fetchedResultsController.fetchedObjects?.count, count > 0 {
                fetchedResultsController.delegate = self
                DispatchQueue.main.async {
                    self.collectionView?.reloadData()
                }
            }
        } catch {
            
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
extension AlbumCollectionViewController: UICollectionViewDataSource {
    
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
        
        let flick = fetchedResultsController.object(at: indexPath)
        
        // Configure the cell
        cell.imageView.image = UIImage(named: "DefaultCVCellImage")
        cell.activityIndicator.isHidden = false
        cell.activityIndicator.startAnimating()
        
        if let imageData = flick.image {
            print("GOOD image")

            if let image = UIImage(data: imageData as Data) {
                cell.imageView.image = image
                cell.activityIndicator.isHidden = true
                cell.activityIndicator.stopAnimating()
            }
        }
        else if let urlString = flick.urlString,
            let url = URL(string: urlString) {
            
            let networking = Networking()
            networking.dataTaskForURL(url) { (data, error) in
                
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

extension AlbumCollectionViewController: NSFetchedResultsControllerDelegate {
    
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        print("willChangeContent , count: \(String(describing: controller.fetchedObjects?.count))")
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        
        switch type {
        case .insert:
            print("didChange -insert , count: \(String(describing: controller.fetchedObjects?.count))")
        case .delete:
            print("didChange -delete , count: \(String(describing: controller.fetchedObjects?.count))")
        case .move:
            print("didChange -move , count: \(String(describing: controller.fetchedObjects?.count))")
        case .update:
            print("didChange -update , count: \(String(describing: controller.fetchedObjects?.count))")
        }
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        print("didChangeContent , count: \(String(describing: controller.fetchedObjects?.count))")
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange sectionInfo: NSFetchedResultsSectionInfo, atSectionIndex sectionIndex: Int, for type: NSFetchedResultsChangeType) {
        
        print("didChange sectionInfo")
    }
}
