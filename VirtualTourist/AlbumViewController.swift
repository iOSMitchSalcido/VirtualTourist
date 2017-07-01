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
    
    // constants
    let CELL_SPACING: CGFloat = 2.0     // spacing between cells
    let CELLS_PER_ROW: CGFloat = 4.0    // number of cells per row, same for both portrait and landscape orientation
    let DOWNLOAD_COMPLETE: Float = 1.0  // constant.. indicates completion of download
    
    // view mode..used to test/steer how view is currently presented
    enum AlbumViewingMode {
        case normal         // normal, collectionView is visible
        case editing        // collectionView is visible, but editable (select/delete)
        case imagePreview   // previewing a image selected in the collectionView
        case downloading    // download in progress
    }
    
    // initialize in normal mode
    var mode: AlbumViewingMode = .normal
    
    // gr used for dismissing imagePreviewScrollView
    var tapGr: UITapGestureRecognizer?
    
    // view objects
    @IBOutlet weak var collectionView: UICollectionView!            // collection view showing flicks
    @IBOutlet weak var flowLayout: UICollectionViewFlowLayout!      // ref to CV flowLayout
    @IBOutlet weak var imagePreviewScrollView: UIScrollView!        // scrollView for flick preview

    var progressView: UIProgressView?   // indicate flick download progress

    var trashBbi: UIBarButtonItem!
    var reloadBbi: UIBarButtonItem!
    
    // ref to stack, context, and Pin ..set in invoking VC
    var stack: CoreDataStack!
    var context: NSManagedObjectContext!
    
    // ref to Pin
    var pin: Pin!
    
    // NSFetchedResultController
    var fetchedResultsController: NSFetchedResultsController<Flick>!
    
    // array of cell indexPaths for cell that are currently selected (checkmark, ready to delete)
    var selectedCellsIndexPaths = [IndexPath]()
        
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // view title
        title = pin.title
        
        // show toolbar
        navigationController?.setToolbarHidden(false, animated: false)
        
        // hide scrollView, disable touch
        imagePreviewScrollView.alpha = 0.0
        imagePreviewScrollView.isUserInteractionEnabled = false
        
        trashBbi = UIBarButtonItem(barButtonSystemItem: .trash,
                                   target: self,
                                   action: #selector(trashBbiPressed(_:)))
        reloadBbi = UIBarButtonItem(barButtonSystemItem: .refresh,
                                    target: self,
                                    action: #selector(reloadBbiPressed(_:)))
        
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
            
            // test download progress. non-nil indicates download in progress
            if let progress = downloadProgress() {
                
                if progress < DOWNLOAD_COMPLETE {
                    mode = .downloading
                }
                else {
                    configureImagePreviewScrollView()
                }
            }
        } catch {
            //TODO: error handling
        }
        
        // configure bars
        configureBars()
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
    
    // handle view editing
    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        
        if editing {
            // editing..set mode to editing
            mode = .editing
        }
        else {
            // not editing. Set mode to normal and clear selectedCells
            mode = .normal
            selectedCellsIndexPaths.removeAll()
        }
        
        // update bars, reload
        configureBars()
        collectionView.reloadData()
    }
    
    // handle showing/dismissing imagePreviewScrollView
    func singleTapDetected(_ sender: UITapGestureRecognizer) {
        
        // test mode
        switch mode {
        case .imagePreview:
            
            // currently in imagePreview mode (scrollView is visible)
            
            // ..return to normal mode
            mode = .normal
            configureBars()
            
            // UI
            imagePreviewScrollView.isUserInteractionEnabled = false
            collectionView.isUserInteractionEnabled = true
            
            // remove gr
            if tapGr != nil {
                view.removeGestureRecognizer(tapGr!)
                tapGr = nil
            }
            
            // animate in/out UI
            UIView.animate(withDuration: 0.3) {
                
                self.imagePreviewScrollView.alpha = 0.0
                self.collectionView.alpha = 1.0
            }
        default:
            break
        }
    }
    
    // handle trash bbi..delete flicks from collectionView
    func trashBbiPressed(_ sender: UIBarButtonItem) {
        
        // iterate, delete flick, then clear selectedCells
        for indexPath in selectedCellsIndexPaths {
            let flick = fetchedResultsController.object(at: indexPath)
            context.delete(flick)
        }
        selectedCellsIndexPaths.removeAll()
        
        // save
        do {
            try context.save()
            
            // update scrollView
            configureImagePreviewScrollView()
            
            // if no flicks, conclude editing
            if fetchedResultsController.fetchedObjects?.count == 0 {
                setEditing(false, animated: true)
            }
            else {
                // nothing selected, disable trash
                trashBbi.isEnabled = false
            }
        } catch {
            //TODO: handle error
        }
    }
    func reloadBbiPressed(_ sender: UIBarButtonItem) {
        
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
        
        // test if editing..dim to indicate editing
        if isEditing {
            cell.imageView.alpha = 0.6
        }
        else {
            cell.imageView.alpha = 1.0
        }
        
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
    
    // handle cell selection..also deselection
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {

        switch mode {
        case .normal:
            
            // currently in normal mode. Transition to imagePreview mode
            mode = .imagePreview
            configureBars()
            
            // UI interaction
            imagePreviewScrollView.isUserInteractionEnabled = true
            collectionView.isUserInteractionEnabled = false
            
            // add tap gr to detect end of imagePreview mode
            tapGr = UITapGestureRecognizer(target: self,
                                           action: #selector(singleTapDetected(_:)))
            tapGr?.numberOfTapsRequired = 1
            view.addGestureRecognizer(tapGr!)
            
            // set scroll location to flick/cell selected
            let frame = imagePreviewScrollView.frame
            let xOrg = CGFloat(indexPath.row) * frame.size.width
            let point = CGPoint(x: xOrg, y: 0)
            imagePreviewScrollView.setContentOffset(point, animated: false)
            
            // animate in/out UI
            UIView.animate(withDuration: 0.3) {
                
                self.imagePreviewScrollView.alpha = 1.0
                self.collectionView.alpha = 0.0
            }
        case .editing:
            
            // currently in editing mode. Handle cell selection and deselection (add/remove checkmark)
            
            // test selection state. Cell is selected if indexPath is in selectedCellsIndexPaths
            if let index = selectedCellsIndexPaths.index(of: indexPath) {
                // is selected...remove (deselect)
                selectedCellsIndexPaths.remove(at: index)
            }
            else {
                // not selected..select
                selectedCellsIndexPaths.append(indexPath)
            }
            
            // trash enable state
            trashBbi.isEnabled = !selectedCellsIndexPaths.isEmpty
            
            // update CV
            collectionView.reloadItems(at: [indexPath])
        default:
            break
        }
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
            if let indexPath = indexPath {
                
                if let imageData = fetchedResultsController.object(at: indexPath).image as Data?,
                    let image = UIImage(data: imageData),
                    let cell = collectionView.cellForItem(at: indexPath) as? PhotoCell{
                    
                    cell.imageView.image = image
                    cell.activityIndicator.stopAnimating()
                    cell.activityIndicator.isHidden = true
                }
            }
        }
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        print("didChangeContent , count: \(String(describing: controller.fetchedObjects?.count))")
        
        /*
         Handle UI while downloading. Test download progress, set UI elements
         to indicate status of downloading when complete
        */

        // test progressView to indicate if downloading
        if let progressView = progressView,
            let progress = downloadProgress() {
            
            if progress < DOWNLOAD_COMPLETE {
                // download still in progress (progress < 1.0)
                progressView.setProgress(progress, animated: true)
            }
            else {
                // done downloading (progress >= 1.0
                
                // mode
                mode = .normal
                configureBars()
                
                // config scrollView with images
                configureImagePreviewScrollView()
            }
        }
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange sectionInfo: NSFetchedResultsSectionInfo, atSectionIndex sectionIndex: Int, for type: NSFetchedResultsChangeType) {
    }
}

// helper functions
extension AlbumViewController {
    
    // return download progress 0.0 -> no downloads yet. 1.0 -> downloads complete
    func downloadProgress() -> Float? {
        
        // verify valid objects
        guard let fetchedObjects = fetchedResultsController.fetchedObjects else {
            return nil
        }
        
        // get count, test for zero objects and return 0.0
        let count = Float(fetchedObjects.count)
        if count == 0.0 {
            return nil
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
    
    // load scrollView
    func configureImagePreviewScrollView() {
        
        // test for objects
        guard let flicks = fetchedResultsController.fetchedObjects else {
            return
        }
        
        // remove all imageViews in scrollView
        // tag is set when creating imageView..used to id the view in scrollView
        let imageViews = imagePreviewScrollView.subviews
        for view in imageViews {
            if view.tag >= 100 {
                view.removeFromSuperview()
            }
        }
        
        // populate scrollView. Accumulate size (content size) while populating
        
        // imageView frame will be same size as scrollView frame
        var frame = imagePreviewScrollView.frame
        frame.origin.x = 0
        frame.origin.y = 0
        
        // size for contentSize...will accumulate width as views are created/added
        var size = CGSize(width: 0.0, height: frame.height)
        
        // id imageViews in scrollView
        var tag: Int = 100
        
        // iterate thru flicks
        for flick in flicks {
            
            // verift valid image data and good image
            if let imageData = flick.image as Data?,
                let image = UIImage(data: imageData) {
                
                // create imageView
                let imageView = UIImageView(frame: frame)
                imageView.image = image
                imageView.contentMode = .scaleToFill
                imageView.tag = tag
                tag = tag + 1
                size.width = size.width + frame.size.width
                frame.origin.x = frame.origin.x + frame.size.width
                imagePreviewScrollView.addSubview(imageView)
            }
        }
        
        // set content size
        imagePreviewScrollView.contentSize = size
    }
    
    // configure bbi's on nav/tool bar
    func configureBars() {
        
        progressView = nil
        
        switch mode {
        case .downloading:
            progressView = UIProgressView(progressViewStyle: .default)
            let progressBbi = UIBarButtonItem(customView: progressView!)
            let flexBbi = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
            setToolbarItems([flexBbi, progressBbi, flexBbi], animated: true)
            navigationItem.setRightBarButton(nil, animated: true)
            navigationItem.setLeftBarButton(nil, animated: true)
        case .normal:
            navigationItem.setLeftBarButton(nil, animated: true)
            if (fetchedResultsController.fetchedObjects?.count)! > 0 {
                navigationItem.setRightBarButton(editButtonItem, animated: true)
            }
            else {
                navigationItem.setRightBarButton(nil, animated: true)
            }
            let flexBbi = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
            setToolbarItems([flexBbi, reloadBbi], animated: true)
        case .imagePreview:
            setToolbarItems(nil, animated: true)
            navigationItem.setLeftBarButton(nil, animated: true)
            navigationItem.setRightBarButton(nil, animated: true)
        case .editing:
            navigationItem.setLeftBarButton(nil, animated: true)
            let flexBbi = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
            setToolbarItems([flexBbi, trashBbi], animated: true)
            trashBbi.isEnabled = false
        }
    }
}
