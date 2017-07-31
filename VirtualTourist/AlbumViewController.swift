//
//  AlbumViewController.swift
//  VirtualTourist
//
//  Created by Online Training on 6/16/17.
//  Copyright © 2017 Mitch Salcido. All rights reserved.
//
/*
 About AlbumViewController.swift:
 Handle presentation of an album of flicks (photos) that have been downloaded from Flickr. Flick's are attached to a Pin managed object.
 
- collectionView for presenting downloaded flicks.
- scrollView to preview a flick when collectionView cell is tapped.
- NSFetchedResultsController to handle loading flicks into collectionView, including frc delegate
  to handle loading flicks while still actively downloading.
 */

import UIKit
import CoreData

class AlbumViewController: UIViewController {
    
    // constants for collectionView cell size and spacing
    let CELL_SPACING: CGFloat = 2.0     // spacing between cells
    let CELLS_PER_ROW: CGFloat = 4.0    // number of cells per row, same for both portrait and landscape orientation
    
    // constant for download complete... < 1.0 still downloading
    // ..pertinent when frc is still in the process of downloading flicks
    let DOWNLOAD_COMPLETE: Float = 1.0
    
    // ref to annotation who's flicks are being presented .. set in invoking VC
    var annotation: VTAnnotation!
    
    // ref to stack, context, and Pin ..set in invoking VC
    var stack: CoreDataStack!
    
    // view mode enum ..used to track/test/steer how view is currently and UI is presented
    enum AlbumViewingMode {
        case preDownloading // awaiting initial data (flickr url string data)
        case downloading    // download in progress (flickr image data)
        case normal         // normal, collectionView is visible
        case editing        // collectionView is visible, but editable (select/delete)
        case imagePreview   // previewing an image selected in the collectionView
    }
    
    // track view mode. Initialize in preDownloading mode
    var mode: AlbumViewingMode = .preDownloading
    
    // gr used for dismissing imagePreviewScrollView
    // created and attached to view when cell is tapped to preview a flick. gr is removed from view
    // when view is tapped to dismiss imagePreviewScrollView
    var tapGr: UITapGestureRecognizer?
    
    // view objects
    @IBOutlet weak var collectionView: UICollectionView!            // collection view showing flicks
    @IBOutlet weak var flowLayout: UICollectionViewFlowLayout!      // ref to CV flowLayout
    @IBOutlet weak var imagePreviewScrollView: UIScrollView!        // scrollView for flick preview
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!  // activity indicator for pre-download status
    var progressView: UIProgressView!                               // bar to indicate download status..in toolbar
    
    // ref to trashBbi...needed to enable/disable bbi as flicks are selected/deselected
    var trashBbi: UIBarButtonItem!
    
    // NSFetchedResultController
    var fetchedResultsController: NSFetchedResultsController<Flick>!
    
    // array of cell indexPaths for cells that are currently selected (checkmark, ready to delete)
    // used to track cells to be deleted when trash bbi pressed
    var selectedCellsIndexPaths = [IndexPath]()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // view title
        title = annotation.pin?.title
        
        // show toolbar
        navigationController?.setToolbarHidden(false, animated: false)
        
        // hide activity indicator
        activityIndicator.isHidden = true
        
        // hide imagePreviewScrollView, disable touch
        // ..use alpha to hide, will be animating in/out
        imagePreviewScrollView.alpha = 0.0
        imagePreviewScrollView.isUserInteractionEnabled = false

        // progressView. Will be showing and animating out, postioned on navBar in viewWillLayoutSubviews
        // to accomodate view rotation
        progressView = UIProgressView(progressViewStyle: .bar)
        progressView.progress = 0.7
        progressView.alpha = 0.0
        
        /*
         Core Data:
         create a fetch request and attached to frc
         - sort on url string of flick
         - predicate is pin... flick belongs to pin
        */
        let fetchRequest: NSFetchRequest<Flick> = Flick.fetchRequest()
        let sort = NSSortDescriptor(key: #keyPath(Flick.urlString), ascending: true)
        let predicate = NSPredicate(format: "pin == %@", annotation.pin!)
        fetchRequest.predicate = predicate
        fetchRequest.sortDescriptors = [sort]
        fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest,
                                                           managedObjectContext: stack.context,
                                                           sectionNameKeyPath: nil,
                                                           cacheName: nil)
        fetchedResultsController.delegate = self
        
        // perform fetch
        do {
            try fetchedResultsController.performFetch()
            
            /*
             determine view mode from possible flick download states....test in this order
             1) predownloading:
                isDownloading, flick count = 0
             2) downloading:
                isDownloading, flick count > 0
                !isDownloading, !downloadComplete ..need to complete download
             3) normal
             */
            
            if (annotation.pin?.isDownloading)! && (fetchedResultsController.fetchedObjects?.isEmpty)! {
                // pin isDownloading, no flicks yet retrieved
                mode = .preDownloading
            }
            else if (annotation.pin?.isDownloading)! && !(fetchedResultsController.fetchedObjects?.isEmpty)! {
                // pin is downloading, flicks have been retrieved
                mode = .downloading
            }
            else if !(annotation.pin?.isDownloading)! && !(annotation.pin?.downloadComplete)! {
                // not downloading and incomplete download..
                mode = .downloading
                continueFlickDownload() // continue downloading any unloaded flicks
            }
            else {
                // complete or no flicks
                mode = .normal
            }
            
            // configure UI
            configureBars()
            
            // scrollView
            configureImagePreviewScrollView()
        } catch {
            // fetch error..present alert
            presentAlertForError(VTError.coreData(error.localizedDescription))
        }
    }
    
    // handle collectionView layout and progressView
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        
        // vertical scroll
        flowLayout.scrollDirection = .vertical
        
        // spacing between rows/columns
        flowLayout.minimumLineSpacing = CELL_SPACING
        flowLayout.minimumInteritemSpacing = CELL_SPACING
        
        // create/set itemSize for cell
        let widthAvailableForCellsInRow = (collectionView?.frame.size.width)! - (CELLS_PER_ROW - 1.0) * CELL_SPACING
        flowLayout.itemSize = CGSize(width: widthAvailableForCellsInRow / CELLS_PER_ROW,                                     height: widthAvailableForCellsInRow / CELLS_PER_ROW)
        
        // update progressView to correct postion on navBar
        if let navBar = navigationController?.navigationBar {
            
            progressView.frame.size.width = navBar.frame.size.width
            progressView.frame.origin.x = 0.0
            progressView.frame.origin.y = navBar.frame.size.height - progressView.frame.height
            navBar.addSubview(progressView)
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // remove progressView from navBar...otherwise will be visible in invoking VC
        progressView?.removeFromSuperview()
    }
    
    // handle view editing
    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        
        /*
         handle placing view into editing mode. In editing mode, collectionView is dimmed slightly and
         subsequent taps on cv cells will place a "checkmark" to indicate ready for deletion upon
         pressing of trash button.
        */
        
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
    
    // action for single-tap gr
    func singleTapDetected(_ sender: UITapGestureRecognizer) {
        
        /*
         handle removing view from imagePreview mode
         ..view is currently in imagePreview mode. Return to normal
         mode and remove gr from view to prevent from receiving touch
         events.
         ..gr is added to view when cell is tapped and mode is changed to imagePreview
        */
        
        // ..return to normal mode
        mode = .normal
        configureBars()
        
        // UI touch response
        imagePreviewScrollView.isUserInteractionEnabled = false
        collectionView.isUserInteractionEnabled = true
        
        // remove gr
        if tapGr != nil {
            view.removeGestureRecognizer(tapGr!)
            tapGr = nil
        }
        
        // animate CV/imagePreview in/out
        UIView.animate(withDuration: 0.3) {
            
            self.collectionView.alpha = 1.0
            self.imagePreviewScrollView.alpha = 0.0
        }
    }
    
    // handle trash bbi..delete flicks from collectionView
    func trashBbiPressed(_ sender: UIBarButtonItem) {
        
        /*
         delete currently selected flicks in CV. Selected flicks are maintained as
         indexPaths in array selectedCellsIndexPaths. Deletion consists of deleting
         flicks from context and then removing associated indexPath from selectedCellsIndexPaths
         array
        */
        
        // perform deletion on private queue
        let privateContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        privateContext.parent = stack.context
        privateContext.perform {
            
            // iterate, delete flick from context
            for indexPath in self.selectedCellsIndexPaths {
                
                // retireve flick, then bring into private context using objectID..delete
                let flick = self.fetchedResultsController.object(at: indexPath)
                let privateFlick = privateContext.object(with: flick.objectID) as! Flick
                privateContext.delete(privateFlick)
            }
            
            // clear out indexPaths from array
            self.selectedCellsIndexPaths.removeAll()
            
            // save
            do {
                try privateContext.save()
                self.stack.context.performAndWait {
                    do {
                        try self.stack.context.save()
                    } catch {
                        print("error: \(error.localizedDescription)")
                    }
                }
                
                // update scrollView to match collectionView flicks
                DispatchQueue.main.async {
                    self.configureImagePreviewScrollView()
                }
                
                // if no flicks, conclude editing
                if (self.fetchedResultsController.fetchedObjects?.isEmpty)! {
                    DispatchQueue.main.async {
                        self.setEditing(false, animated: true)
                    }
                }
                else {
                    // nothing selected, disable trash
                    DispatchQueue.main.async {
                        self.trashBbi.isEnabled = false
                    }
                }
            } catch {
                print("error: \(error.localizedDescription)")
            }
        }
    }
    
    // handle album reload
    func reloadBbiPressed(_ sender: UIBarButtonItem) {
     
        /*
         Reload album with a new set of flicks (discard flicks currently in cv.
         Present an alert/proceed if flick count > 0
        */
        
        // present proceed.cancel alert..about to delete all flicks
        if (fetchedResultsController.fetchedObjects?.count)! > 0 {
            
            presentProceedCancelAlert(title: "Load new album",
                                      message: "Delete all flicks and replace with newly downloaded album ?") {
                                        (UIAlertAction) in
                                        
                                        self.reloadAlbum()
            }
        }
        else {
            reloadAlbum()
        }
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
    
    // sections
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        
        guard let sections = fetchedResultsController.sections else {
            return 0
        }
        return sections.count
    }
    
    // item count
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        
        guard let section = fetchedResultsController.sections?[section] else {
            return 0
        }
        return section.numberOfObjects
    }
    
    // cell
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
            
            // valid imageData...place image in cell, hide activityIndicator
            
            if let image = UIImage(data: imageData as Data) {
                cell.imageView.image = image
                cell.activityIndicator.isHidden = true
                cell.activityIndicator.stopAnimating()
            }
        }
        else {
         
            // imageData not yet downloaded..place default image  and activityIndicator in cell
            
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

        /*
         delegate method handles:
            - If vc in currently in .normal mode, placing vc into imagePreview mode when a cell is tapped
            - If in .editing mode, selecting/deselecting a cell/flick for deletion
        */
        
        switch mode {
        case .normal:
            
            // currently in normal mode. Transition to imagePreview mode
            mode = .imagePreview
            configureBars()
            
            // UI interaction
            imagePreviewScrollView.isUserInteractionEnabled = true
            collectionView.isUserInteractionEnabled = false
            
            // add tap gr to detect end of imagePreview mode
            // ..action method handles placing view back into .normal mode.
            tapGr = UITapGestureRecognizer(target: self,
                                           action: #selector(singleTapDetected(_:)))
            tapGr?.numberOfTapsRequired = 1
            view.addGestureRecognizer(tapGr!)
            
            // set scroll location to flick/cell that was tapped
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
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        
        switch type {
        case .insert:
            collectionView.reloadData()
        case .delete:
            collectionView.reloadData()
        case .update:
            // handle updating cell with newly downloaded flick
            if let indexPath = indexPath {
                
                // get flick image data, image, and cell
                if let imageData = fetchedResultsController.object(at: indexPath).image as Data?,
                    let image = UIImage(data: imageData),
                    let cell = collectionView.cellForItem(at: indexPath) as? PhotoCell{
                    
                    // update cell with flick, hide activityIndicator
                    cell.imageView.image = image
                    cell.activityIndicator.stopAnimating()
                    cell.activityIndicator.isHidden = true
                }
            }
        default:
            break
        }
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        
        /*
         Handle UI while downloading. Test download progress, set UI elements
         to indicate status of downloading when complete
        */

        switch mode {
        case .preDownloading:
            /*
             currently in .preDownloading mode (no flicks received yet)
             Test download progress. When at least one download has been received, remove
             from preDownloading and place into .downloading mode
            */
            
            if let progress = downloadProgress(),
                progress > 0.0 {
                
                mode = .downloading
                configureBars()
            }
        case .downloading:
            /*
             currently downloading.
             test downloadProgress and update progressView. When download has been complete, remove
             from .download mode and place in .normal mode
            */
            if let progress = downloadProgress() {
                
                progressView.setProgress(progress, animated: true)
                
                // done downloading (progress >= 1.0)
                if progress >= DOWNLOAD_COMPLETE {
                    
                    // return to normal mode
                    mode = .normal
                    configureBars()
                    
                    // config scrollView with images
                    configureImagePreviewScrollView()
                    
                    // reload table...
                    collectionView.reloadData()
                    
                    //animate out progressView
                    UIView.animate(withDuration: 0.3) {
                        self.progressView.alpha = 0.0
                    }
                }
            }
        default:
            break
        }
    }
}

// helper function
extension AlbumViewController {
    
    // return download progress 0.0 -> no downloads yet. 1.0 -> downloads complete
    func downloadProgress() -> Float? {
        
        /*
         return download progress.
         progress in non-nil image data count / total count
         used for progressView updates
        */
        
        // verify valid objects
        guard let fetchedObjects = fetchedResultsController.fetchedObjects else {
            return nil
        }
        
        // count non-nil image, sum
        var downloadCount: Float = 0.0
        for flick in fetchedResultsController.fetchedObjects! {
            if flick.image != nil {
                downloadCount = downloadCount + 1.0
            }
        }

        // get count
        let count = Float(fetchedObjects.count)
        if count == 0.0 {
            return 0.0
        }
        
        // return ratio
        return downloadCount / Float(fetchedObjects.count)
    }
    
    // load imagePreviewScrollView
    func configureImagePreviewScrollView() {
        
        /*
         configure imagePreviewScrollView.
         clear all imageView subviews and reload with existing flicks currently presented in CV
        */
        
        // test for objects
        guard let flicks = fetchedResultsController.fetchedObjects else {
            return
        }
        
        // remove all imageViews in scrollView
        // tag is set when creating imageView..used to id the view in scrollView..want to avoid removing scrollbars
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

        // tag to id imageViews in scrollView
        var tag: Int = 100
        
        // iterate thru flicks
        for flick in flicks {
            
            // verify valid image data and good image
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
        
        /*
         configure the bars depending on view mode
        */
        
        // nil progressView..will be created if downloading
        // TODO: progressView
        //progressView = nil
        
        // flexBbi...used is various modes below...
        let flexBbi = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)

        switch mode {
        case .preDownloading:
            /*
             pre-download. Awaiting URL string download from flickr..
             ...occurs before image data is downloaded.
             */
            
            // show activityIndicator in middle of CV
            activityIndicator.isHidden = false
            activityIndicator.startAnimating()
            
            // nil all bbi's on bars
            setToolbarItems(nil, animated: true)
            navigationItem.setRightBarButton(nil, animated: true)
            break
        case .downloading:
            /*
             Downloading mode. VC is currently in the process of downloading flicks.
             */
            
            // hide activityView in middle of CV....default cells now have activityViews
            activityIndicator.isHidden = true
            activityIndicator.stopAnimating()
            
            // create progressView and update
            // TODO: progressView
            //progressView = UIProgressView(progressViewStyle: .bar)
            if let progress = downloadProgress() {
                
                progressView.alpha = 1.0
                progressView?.progress = progress
            }
            
            // add bbi's to bars
            // TODO: progressView
            //let progressBbi = UIBarButtonItem(customView: progressView!)
            //setToolbarItems([flexBbi, progressBbi, flexBbi], animated: true)
            navigationItem.setRightBarButton(nil, animated: true)
        case .normal:
            /*
             Normal mode. Flicks are presented in collectionView.
             */
            
            // show edit bbi if flicks present
            if let flicks = fetchedResultsController.fetchedObjects,
                flicks.count > 0 {
                navigationItem.setRightBarButton(editButtonItem, animated: true)
            }
            else {
                navigationItem.setRightBarButton(nil, animated: true)
            }
            
            // reload album bbi
            let reloadBbi = UIBarButtonItem(barButtonSystemItem: .refresh,
                                            target: self,
                                            action: #selector(reloadBbiPressed(_:)))
            setToolbarItems([flexBbi, reloadBbi], animated: true)
        case .editing:
            /*
             Editing. VC has been placed in editing mode
             */
            
            // create trashBbi
            trashBbi = UIBarButtonItem(barButtonSystemItem: .trash,
                                       target: self,
                                       action: #selector(trashBbiPressed(_:)))
            trashBbi.isEnabled = false
            setToolbarItems([flexBbi, trashBbi], animated: true)
        case .imagePreview:
            /*
             Image Preview. Flicks are presented in a scrollView
            */
            
            // share bbi in right navbar
            let shareBbi = UIBarButtonItem(barButtonSystemItem: .action,
                                           target: self,
                                           action: #selector(shareFlickBbiPressed(_:)))
            navigationItem.setRightBarButton(shareBbi, animated: true)

            // nil toolbar bbi's
            setToolbarItems(nil, animated: true)
        }
    }
    
    // reload album with new flicks
    func reloadAlbum() {
        
        /*
         Using private queue/context, delete all flicks, then perform task to reload
         a new set of images.
        */
        
        // configure UI
        mode = .preDownloading
        configureBars()
        
        // perform on private context/queue
        let privateContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        privateContext.parent = stack.context
        privateContext.perform {
            
            // retrieve pin. Indicate downloading
            let pin = privateContext.object(with: (self.annotation.pin?.objectID)!) as! Pin
            let flicks = pin.flicks
            pin.isDownloading = true
            
            // delete all flicks
            for flick in flicks! {
                privateContext.delete(flick as! NSManagedObject)
            }
            
            // save..capture flick deletion and isDownloading set to false
            do {
                try privateContext.save()
                
                self.stack.context.performAndWait {
                    do {
                        try self.stack.context.save()
                    } catch let error {
                        print("error: \(error.localizedDescription)")
                    }
                }
            } catch let error {
                print("error: \(error.localizedDescription)")
            }
            
            // begin download of new album using API call
            FlickrAPI().createFlickrAlbumForPin(pin, page: nil) {
                (data, error) in
                
                // test error, show alert if error
                guard error == nil else {
                    DispatchQueue.main.async {
                        self.presentAlertForError(error!)
                    }
                    return
                }
                
                // test data, show alert if bad data
                guard let data = data else {
                    DispatchQueue.main.async {
                        self.presentAlertForError(VTError.networkError("Bad data returned from Flickr."))
                    }
                    return
                }
                
                // create flicks..assign urlString
                for urlString in data {
                    let flick = Flick(context: privateContext)
                    flick.urlString = urlString
                    pin.addToFlicks(flick)
                }
                
                // save...will cause frc to repopulate cv with default image
                do {
                    try privateContext.save()
                    
                    self.stack.context.performAndWait {
                        do {
                            try self.stack.context.save()
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
                                
                                self.stack.context.performAndWait {
                                    do {
                                        try self.stack.context.save()
                                    } catch let error {
                                        print("error: \(error.localizedDescription)")
                                    }
                                }
                            } catch let error {
                                print("error: \(error.localizedDescription)")
                            }
                        }
                    }
                    
                    // done downloading
                    pin.isDownloading = false
                    // save....capture setting download to false
                    do {
                        try privateContext.save()
                        
                        self.stack.context.performAndWait {
                            do {
                                try self.stack.context.save()
                            } catch let error {
                                print("error: \(error.localizedDescription)")
                            }
                        }
                    } catch let error {
                        print("error: \(error.localizedDescription)")
                    }
                } catch {
                    print("error: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func continueFlickDownload() {
        
        /*
         finish downloading flicks for a Pin that has flicks with nil image data
         ..this condition might occur if app was terminated during a download, leaving
         flicks with nil image data that still needs download.
        */
        
        // perform on private context/queue
        let privateContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        privateContext.parent = stack.context
        privateContext.perform {
            
            // retrieve pin, set isDownloading
            let pin = privateContext.object(with: (self.annotation.pin?.objectID)!) as! Pin
            pin.isDownloading = true
            
            // request
            let request: NSFetchRequest<Flick> = Flick.fetchRequest()
            let sort = NSSortDescriptor(key: #keyPath(Flick.urlString), ascending: true)
            let predicate = NSPredicate(format: "pin == %@", pin)
            request.predicate = predicate
            request.sortDescriptors = [sort]
            
            // perform fetch
            do {
                let flicks = try privateContext.fetch(request)
                
                // iterate, retrieve image data
                for flick in flicks {
                    
                    if flick.image == nil,
                        let urlString = flick.urlString,
                        let url = URL(string: urlString),
                        let imageData = NSData(contentsOf: url) {
                        
                        flick.image = imageData
                        
                        // save
                        do {
                            try privateContext.save()
                            
                            self.stack.context.performAndWait {
                                do {
                                    try self.stack.context.save()
                                } catch let error {
                                    print("error: \(error.localizedDescription)")
                                }
                            }
                        } catch let error {
                            print("error: \(error.localizedDescription)")
                        }
                    }
                }
                // done downloading
                pin.isDownloading = false
                
                // save
                do {
                    try privateContext.save()
                    
                    self.stack.context.performAndWait {
                        do {
                            try self.stack.context.save()
                        } catch let error {
                            print("error: \(error.localizedDescription)")
                        }
                    }
                } catch let error {
                    print("error: \(error.localizedDescription)")
                }
            } catch {
                print("error: \(error.localizedDescription)")
            }
        }
    }
}
