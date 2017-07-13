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
        case imagePreview   // previewing an image selected in the collectionView
        case downloading    // download in progress
    }
    
    // ref to annotation .. set in invoking VC
    var annotation: VTAnnotation!
    
    // ref to stack, context, and Pin ..set in invoking VC
    var stack: CoreDataStack!
    var context: NSManagedObjectContext!
    
    // initialize in normal mode
    var mode: AlbumViewingMode = .normal
    
    // gr used for dismissing imagePreviewScrollView
    var tapGr: UITapGestureRecognizer?
    
    // view objects
    @IBOutlet weak var collectionView: UICollectionView!            // collection view showing flicks
    @IBOutlet weak var flowLayout: UICollectionViewFlowLayout!      // ref to CV flowLayout
    @IBOutlet weak var imagePreviewScrollView: UIScrollView!        // scrollView for flick preview

    // indicate flick download progress. Ref needed to update progress and downloads are in process
    var progressView: UIProgressView?

    // ref to trashBbi. Ref needed to enable/disable bbi as flicks are selected/deselected
    var trashBbi: UIBarButtonItem!
    
    // NSFetchedResultController
    var fetchedResultsController: NSFetchedResultsController<Flick>!
    
    // array of cell indexPaths for cell that are currently selected (checkmark, ready to delete)
    var selectedCellsIndexPaths = [IndexPath]()
        
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // view title
        title = annotation.pin?.title
        
        // show toolbar
        navigationController?.setToolbarHidden(false, animated: false)
        
        // hide scrollView, disable touch
        imagePreviewScrollView.alpha = 0.0
        imagePreviewScrollView.isUserInteractionEnabled = false
        
        // create trashBbi
        trashBbi = UIBarButtonItem(barButtonSystemItem: .trash,
                                   target: self,
                                   action: #selector(trashBbiPressed(_:)))
        
        // Core Data: Request, Sort/Predicate, and Controller
        let fetchRequest: NSFetchRequest<Flick> = Flick.fetchRequest()
        let sort = NSSortDescriptor(key: #keyPath(Flick.urlString), ascending: true)
        let predicate = NSPredicate(format: "pin == %@", annotation.pin!)
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
                print("non-nil download progress")
                
                if progress < DOWNLOAD_COMPLETE {
                    mode = .downloading
                }
                else {
                    configureImagePreviewScrollView()
                }
            }
            else {
                print("nil progress **")
            }
        } catch {
            //TODO: error handling
            print("unable to fetch pin")
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
     
        print("reloadBbiPressed")
        reloadAlbum()
    }
    
    // handle sharing flick
    func shareFlickBbiPressed(_ sender: UIBarButtonItem) {
        
        /*
         function to handle sharing a flick. The flick is retrieved from the imagePreviewScrollView
         and presented in a UIActivityViewVC for sharing.
        */
        
        // determine index of flick in scrollView
        let offset = imagePreviewScrollView.contentOffset.x
        let index = Int(offset / imagePreviewScrollView.frame.size.width)
        
        // create an indexPath and retrieve flick from frc
        let indexPath = IndexPath(row: index, section: 0)
        let flick = fetchedResultsController.object(at: indexPath)
        
        // verify good flick...present activityVC. Inculde a message and the flick
        if let imageData = flick.image as Data?,
            let image = UIImage(data: imageData) {
            
            var message = "Hello"
            if let title = annotation.pin?.title {
                message = message + " from " + title + " !"
            }
            let controller = UIActivityViewController(activityItems: [message, image], applicationActivities: nil)
            present(controller, animated: true)
        }
    }
}

// MARK: UICollectionView DataSource methods
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
        else {
         
            cell.imageView.image = UIImage(named: "DefaultCVCellImage")
            cell.activityIndicator.isHidden = false
            cell.activityIndicator.startAnimating()
        }
        return cell
    }
}

// MARK: UICollectionView Delegate methods
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

// MARK: NSFetchedResultsController Delegate methods
extension AlbumViewController: NSFetchedResultsControllerDelegate {
    
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        
        switch type {
        case .insert:
            print("didChange -insert , count: \(String(describing: controller.fetchedObjects?.count))")
            collectionView.reloadData()
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
            print("nil fetchedObjects")
            return nil
        }
        
        // get count, test for zero objects and return 0.0
        let count = Float(fetchedObjects.count)
        if count == 0 {
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
            /*
             Downloading mode. VC is currently in the process of downloading flicks.
             */
            progressView = UIProgressView(progressViewStyle: .default)
            let progressBbi = UIBarButtonItem(customView: progressView!)
            let flexBbi = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
            setToolbarItems([flexBbi, progressBbi, flexBbi], animated: true)
            navigationItem.setRightBarButton(nil, animated: true)
            navigationItem.setLeftBarButton(nil, animated: true)
        case .normal:
            /*
             Normal mode. Flicks are presented in collectionView.
             */
            if let flicks = fetchedResultsController.fetchedObjects,
                flicks.count > 0 {
                navigationItem.setRightBarButton(editButtonItem, animated: true)
            }
            else {
                navigationItem.setRightBarButton(nil, animated: true)
            }
            navigationItem.setLeftBarButton(nil, animated: true)
            let flexBbi = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
            let reloadBbi = UIBarButtonItem(barButtonSystemItem: .refresh,
                                            target: self,
                                            action: #selector(reloadBbiPressed(_:)))
            setToolbarItems([flexBbi, reloadBbi], animated: true)
        case .imagePreview:
            /*
             Image Preview. Flicks are presented in a scrollView
            */
            setToolbarItems(nil, animated: true)
            navigationItem.setLeftBarButton(nil, animated: true)
            
            let shareBbi = UIBarButtonItem(barButtonSystemItem: .action,
                                           target: self,
                                           action: #selector(shareFlickBbiPressed(_:)))
            navigationItem.setRightBarButton(shareBbi, animated: true)
        case .editing:
            /*
             Editing. VC has been placed in editing mode
            */
            navigationItem.setLeftBarButton(nil, animated: true)
            let flexBbi = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
            setToolbarItems([flexBbi, trashBbi], animated: true)
            trashBbi.isEnabled = false
        }
    }
    
    func reloadAlbum() {
        
        mode = .downloading
        configureBars()
        
        let privateContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        privateContext.parent = context
        privateContext.perform {
            
            let pin = privateContext.object(with: (self.annotation.pin?.objectID)!) as! Pin
            let flicks = pin.flicks
            for flick in flicks! {
                privateContext.delete(flick as! NSManagedObject)
            }
            
            do {
                try privateContext.save()
                
                self.context.performAndWait {
                    do {
                        try self.context.save()
                    } catch let error {
                        print("error: \(error.localizedDescription)")
                    }
                }
            } catch let error {
                print("error: \(error.localizedDescription)")
            }
            
            let flickrApi = FlickrAPI()
            flickrApi.createFlickrAlbumForPin(pin, page: nil) {
                (data, error) in
                
                guard error == nil else {
                    return
                }
                
                guard let data = data else {
                    return
                }
                
                for urlString in data {
                    let flick = Flick(context: privateContext)
                    flick.urlString = urlString
                    pin.addToFlicks(flick)
                }
                
                do {
                    try privateContext.save()
                    
                    self.context.performAndWait {
                        do {
                            try self.context.save()
                        } catch let error {
                            print("error: \(error.localizedDescription)")
                        }
                    }
                } catch let error {
                    print("error: \(error.localizedDescription)")
                }
                
                
                /*
                 Now pull image data..
                 Want to sort by urlString to match ordering used in FetchResultController
                 in AlbumVC..for aesthetic reasons..forces images to load in AlbumVC cells
                 in the order of the cells (top to bottom of collectionView)
                 */
                
                // request
                let request: NSFetchRequest<Flick> = Flick.fetchRequest()
                let sort = NSSortDescriptor(key: #keyPath(Flick.urlString), ascending: true)
                let predicate = NSPredicate(format: "pin == %@", pin)
                request.predicate = predicate
                request.sortDescriptors = [sort]
                do {
                    
                    // perform fetch
                    let flicks = try privateContext.fetch(request)
                    
                    // iterate, pull image data and assign to Flick
                    // ..save as each flick is retrieved
                    for flick in flicks {
                        
                        // verify good url, data
                        if let urlString = flick.urlString,
                            let url = URL(string: urlString),
                            let imageData = NSData(contentsOf: url) {
                            
                            // assign data to Flick
                            flick.image = imageData
                            
                            // save
                            do {
                                try privateContext.save()
                                
                                self.context.performAndWait {
                                    do {
                                        try self.context.save()
                                    } catch let error {
                                        print("error: \(error.localizedDescription)")
                                    }
                                }
                            } catch let error {
                                print("error: \(error.localizedDescription)")
                            }
                        }
                    }
                } catch {
                    // bad fetch
                    DispatchQueue.main.async {
                        self.presentAlertForError(VTError.coreData("Unable to retrieve Flicks"))
                    }
                }
            }
        }
    }
}
