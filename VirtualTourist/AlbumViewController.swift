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

    // main view objects
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    // cell presentation contants
    let CELL_SPACING: CGFloat = 2.0     // spacing between cells
    let CELLS_PER_ROW: CGFloat = 4.0    // number of cells per row.same for both portrait and landscape orientation

    // ref to stack, context, and Pin ..set in invoking VC
    var stack: CoreDataStack!
    var context: NSManagedObjectContext!
    
    // ref to Pin
    var pin: Pin!
    
    // new Load. Test bool used to initialize collectionView reload only once, after insert is detected
    var newLoad = false
    
    // bbi's
    var reloadBbi: UIBarButtonItem! // dumps all photo's and replaces with new set of photo's
    var trashBbi: UIBarButtonItem!  // deletes selected photos
    var cancelBbi: UIBarButtonItem! // cancel "delete" operation...deselect photos
    
    // NSFetchedResultController
    var fetchedResultsController: NSFetchedResultsController<Flick>!
    
    var selectedCellsIndexPaths = [IndexPath]()
    // layout
    @IBOutlet weak var flowLayout: UICollectionViewFlowLayout!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // view title
        title = pin.title

        // initialize view in "search" mode..
        activityIndicator.startAnimating()
        activityIndicator.isHidden = false
    
        // create bbi's
        reloadBbi = UIBarButtonItem(barButtonSystemItem: .refresh,
                                                            target: self,
                                                            action: #selector(reloadBbiPressed(_:)))
        trashBbi = UIBarButtonItem(barButtonSystemItem: .trash,
                                   target: self,
                                   action: #selector(trashBbiPressed(_:)))
        cancelBbi = UIBarButtonItem(barButtonSystemItem: .cancel,
                                    target: self,
                                    action: #selector(cancelBbiPressed(_:)))
        
        
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
        
        do {
            try fetchedResultsController.performFetch()
        } catch {
        }
    }
    
    func reloadBbiPressed(_ sender: UIBarButtonItem) {
        
    }
    func trashBbiPressed(_ sender: UIBarButtonItem) {
        
        for indexPath in  selectedCellsIndexPaths {
            context.delete(fetchedResultsController.object(at: indexPath))
        }
        selectedCellsIndexPaths.removeAll()
        do {
            try context.save()
        } catch {
            
        }
        
        navigationItem.setLeftBarButton(nil, animated: true)
        navigationItem.setRightBarButton(reloadBbi, animated: true)
    }
    func cancelBbiPressed(_ sender: UIBarButtonItem) {
        
        let array = selectedCellsIndexPaths
        selectedCellsIndexPaths.removeAll()
        collectionView.reloadItems(at: array)
        navigationItem.setLeftBarButton(nil, animated: true)
        navigationItem.setRightBarButton(reloadBbi, animated: true)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        navigationController?.setToolbarHidden(false, animated: false)
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
        
        collectionView.alpha = 1.0
        activityIndicator.stopAnimating()
        activityIndicator.isHidden = true
        
        let flick = fetchedResultsController.object(at: indexPath)
        
        // Configure the cell
        cell.imageView.image = UIImage(named: "DefaultCVCellImage")
        cell.activityIndicator.isHidden = false
        cell.activityIndicator.startAnimating()
        
        // test if cell is selected for deletion
        cell.selectedImageView.isHidden = !selectedCellsIndexPaths.contains(indexPath)
        
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

extension AlbumViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
        /*
         Handle placing cell in selection state (checkmark in cell) which provides user visual queue
         that cell is ready for deletion. Also deselects cell that is currently selected.
        */
        
        // verift image has been downloaded
        guard fetchedResultsController.object(at: indexPath).image != nil else {
                return
        }
        
        // retireve cell cast as PhotoCell
        let cell = collectionView.cellForItem(at: indexPath) as! PhotoCell
        
        // test if cell is selected(indexPath will be in selectedCellsIndexPaths array)
        if let index = selectedCellsIndexPaths.index(of: indexPath) {
            
            // cell is selected..proceed to deselect
            // remove indexPath from array and hide checkmark
            selectedCellsIndexPaths.remove(at: index)
            cell.selectedImageView.isHidden = true
            
            // test is no selected cells...restore bbi's/UI
            if selectedCellsIndexPaths.count == 0 {
                navigationItem.setLeftBarButton(nil, animated: true)
                navigationItem.setRightBarButton(reloadBbi, animated: true)
            }
        }
        else {
            
            // cell is not selected. Proceed with selecting
            // add indexPath to selectedCellsIndexPaths array, show checkmark
            selectedCellsIndexPaths.append(indexPath)
            cell.selectedImageView.isHidden = false
            
            // test if a selected cell...update bbi's/UI
            if selectedCellsIndexPaths.count == 1 {
                navigationItem.setLeftBarButton(cancelBbi, animated: true)
                navigationItem.setRightBarButton(trashBbi, animated: true)
            }
        }
    }
}

extension AlbumViewController: NSFetchedResultsControllerDelegate {
    
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        print("willChangeContent , count: \(String(describing: controller.fetchedObjects?.count))")
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        
        switch type {
        case .insert:
            print("didChange -insert , count: \(String(describing: controller.fetchedObjects?.count))")
            if !newLoad {
                print("!!newLoad!!")
                collectionView.reloadData()
                newLoad = true
            }
        case .delete:
            collectionView.reloadData()
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
