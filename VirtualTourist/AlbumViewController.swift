//
//  AlbumViewController.swift
//  VirtualTourist
//
//  Created by Online Training on 6/16/17.
//  Copyright © 2017 Mitch Salcido. All rights reserved.
//
/*
 About AlbumViewController.swift:
 Handle presentation of an album of flicks (photos) that have been downloaded from Flickr using a collectionView.
 Flick's are attached to a Pin managed object.
 
 VC has "viewing modes", defined by enum AlbumViewMode below. Modes depend on status of download (predownloading, downloading,
 etc), which is used to steer the presentation of the UI
 
- collectionView for presenting downloaded flicks.
- scrollView to preview a flick when collectionView cell is tapped.
- progressView on navBar to indicate download progress.
- NSFetchedResultsController to handle loading flicks into collectionView, including frc delegate
  to handle loading flicks while still actively downloading.
- functionality to delete flicks
 */

import UIKit
import CoreData

class AlbumViewController: UIViewController {
    
    // ref to Pin who's flicks are being presented .. set in invoking VC
    var pin: Pin!
    
    // ref to stack, context, and Pin ..set in invoking VC
    var stack: CoreDataStack!
    
    // constants for collectionView cell size and spacing
    let collectionViewCellSpacing: CGFloat = 2.0        // spacing between cells
    let collectionViewCellsPerRow: CGFloat = 4.0        // number of cells per row, same for both portrait and landscape orientation
    
    // constant for download complete... < 1.0 still downloading
    // ..pertinent when frc is still in the process of downloading flicks
    let albumDownloadComplete: Float = 1.0
    
    // view mode enum ..used to track/test/steer how view/UI is presented
    enum AlbumViewingMode {
        case preDownloading // awaiting initial data (flickr url string data)
        case downloading    // download in progress (flickr image data)
        case normal         // normal, collectionView is visible
        case editing        // collectionView is visible, but editable (select/delete)
        case imagePreview   // previewing an image selected in the collectionView
        case noFlicksFound  // album has no flicks at Pin location
    }
    
    /*
     171008
     Add FRCProgressStates, for aesthetics, want first default images to transform from small rect to normal size.
     Added enum to track frc insertion states to determine if transform or normal when CV
     is scrolled while in download state
     */
    enum FRCProgressStates {
        case reload
        case inserting
        case doneInserting
    }
    var loadState: FRCProgressStates = .doneInserting
    
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
    @IBOutlet weak var noFlicksImageView: UIImageView!              // imageView to indicate no flicks found
    var progressView: UIProgressView!                               // indicate download status, placed on navbar
    
    // ref to trashBbi...needed to enable/disable bbi as flicks are selected/deselected
    var trashBbi: UIBarButtonItem!
    
    // NSFetchedResultController
    var fetchedResultsController: NSFetchedResultsController<Flick>!
    
    // array of cell indexPaths for cells that are currently selected (checkmark, ready to delete)
    // used to track cells/flicks to be deleted when trash bbi pressed
    var selectedCellsIndexPaths = [IndexPath]()
    
    // store completions for batch updates in collectionView
    var cvBatchCompletionsArray = [()->Void]()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // view title
        if let viewTitle = pin.title {
            title = viewTitle
        }
        else {
            title = "Location"
        }
        
        // show toolbar
        navigationController?.setToolbarHidden(false, animated: false)
        
        // hide activity indicator
        activityIndicator.isHidden = true
        
        // hide noFlicksImageView
        noFlicksImageView.isHidden = true
        
        // hide imagePreviewScrollView, disable touch
        // ..use alpha to hide, will be animating in/out
        imagePreviewScrollView.alpha = 0.0
        imagePreviewScrollView.isUserInteractionEnabled = false

        // progressView. Will be showing and animating out, postioned on navBar in viewWillLayoutSubviews
        // to accomodate view rotation
        progressView = UIProgressView(progressViewStyle: .bar)
        progressView.progress = 0.7
        progressView.alpha = 0.0
        if let navBar = navigationController?.navigationBar {
            navBar.addSubview(progressView)
        }
        
        /*
         Core Data:
         create a fetch request and attached to frc
         - sort on url string of flick
         - predicate is pin... flick belongs to pin
        */
        let fetchRequest: NSFetchRequest<Flick> = Flick.fetchRequest()
        let sort = NSSortDescriptor(key: #keyPath(Flick.urlString), ascending: true)
        let predicate = NSPredicate(format: "pin == %@", pin)
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
             3) No flicks found for Pin
             4) normal
             */
            
            if pin.isDownloading && (fetchedResultsController.fetchedObjects?.isEmpty)! {
                // pin isDownloading, no flicks yet retrieved
                mode = .preDownloading
            }
            else if pin.isDownloading && !(fetchedResultsController.fetchedObjects?.isEmpty)! {
                // pin is downloading, some flicks have been retrieved
                mode = .downloading
            }
            else if pin.noFlicksAtLocation {
                // no flicks found at pin location
                mode = .noFlicksFound
            }
            else {
                // download was completed
                mode = .normal
                configureImagePreviewScrollView()
            }
            
            // configure UI
            configureBars()
        } catch {
            // fetch error..present alert
            presentAlertForLocalizedError(CoreDataError.fetch("Error fetching saved flicks."))
        }
    }
    
    // handle collectionView layout and progressView
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        
        // vertical scroll
        flowLayout.scrollDirection = .vertical
        
        // spacing between rows/columns
        flowLayout.minimumLineSpacing = collectionViewCellSpacing
        flowLayout.minimumInteritemSpacing = collectionViewCellSpacing
        
        // create/set itemSize for cell
        let widthAvailableForCellsInRow = (collectionView?.frame.size.width)! - (collectionViewCellsPerRow - 1.0) * collectionViewCellSpacing
        flowLayout.itemSize = CGSize(width: widthAvailableForCellsInRow / collectionViewCellsPerRow, height: widthAvailableForCellsInRow / collectionViewCellsPerRow)
        
        // update progressView frame on navBar
        if let navBar = navigationController?.navigationBar {
            
            progressView.frame.size.width = navBar.frame.size.width
            progressView.frame.origin.x = 0.0
            progressView.frame.origin.y = navBar.frame.size.height - progressView.frame.height
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // remove progressView from navBar...otherwise will be visible in invoking VC
        progressView?.removeFromSuperview()
        
        // nil..otherwise will keep VC alive and continue updates
        fetchedResultsController.delegate = nil
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
        }
        
        selectedCellsIndexPaths.removeAll()

        // update bars, reload
        configureBars()
        collectionView.reloadData()
    }
    
    // action for single-tap gr
    @objc func singleTapDetected(_ sender: UITapGestureRecognizer) {
        
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
    @objc func trashBbiPressed(_ sender: UIBarButtonItem) {
        
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
            
            // 171022, ARC cleanup
            [weak self] in
            guard let strongSelf = self else {
                return
            }
            
            // iterate, delete flick from context
            for indexPath in strongSelf.selectedCellsIndexPaths {
                
                // retireve flick, then bring into private context using objectID..delete
                let flick = strongSelf.fetchedResultsController.object(at: indexPath)
                let privateFlick = privateContext.object(with: flick.objectID) as! Flick
                privateContext.delete(privateFlick)
            }
            
            // clear out indexPaths from array
            strongSelf.selectedCellsIndexPaths.removeAll()
            
            // save
            do {
                try privateContext.save()
                strongSelf.stack.context.performAndWait {
                    do {
                        try strongSelf.stack.context.save()
                    } catch {
                        print("error: \(error.localizedDescription)")
                    }
                }
                
                // update scrollView to match collectionView flicks
                DispatchQueue.main.async {
                    strongSelf.configureImagePreviewScrollView()
                }
                
                // if no flicks, conclude editing
                if (strongSelf.fetchedResultsController.fetchedObjects?.isEmpty)! {
                    DispatchQueue.main.async {
                        strongSelf.setEditing(false, animated: true)
                    }
                }
                else {
                    // nothing selected, disable trash
                    DispatchQueue.main.async {
                        strongSelf.trashBbi.isEnabled = false
                    }
                }
            } catch {
                print("error: \(error.localizedDescription)")
            }
        }
    }
    
    // handle album reload
    @objc func reloadBbiPressed(_ sender: UIBarButtonItem) {
     
        /*
         Reload album with a new set of flicks (discard flicks currently in cv.
         Present an alert/proceed if flick count > 0
        */

        // reload start..beginning new flick load
        loadState = .reload
        
        // declare function to reload album with new flicks
        func reloadAlbum() {
            
            // configure UI
            mode = .preDownloading
            configureBars()
            
            // download new album
            downloadAlbumForPin(pin, stack: stack)
        }
        
        // present proceed cancel alert if flicks are present..about to delete all flicks
        if (fetchedResultsController.fetchedObjects?.count)! > 0 {
            
            presentProceedCancelAlert(title: "Load new album",
                                      message: "Delete all flicks and replace with newly downloaded album ?") {
                                        [weak self] (UIAlertAction) in
                                        
                                        // 171022, ARC
                                        guard let strongSelf = self else {
                                            return
                                        }
                                        
                                        // delete flicks on private queue
                                        let privateContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
                                        privateContext.parent = strongSelf.stack.context
                                        privateContext.perform {
                                            
                                            let pin = privateContext.object(with: strongSelf.pin.objectID) as! Pin
                                            let flicks = pin.flicks

                                            // delete all flicks
                                            for flick in flicks! {
                                                privateContext.delete(flick as! NSManagedObject)
                                            }
                                            
                                            // save..capture flick deletion
                                            do {
                                                try privateContext.save()
                                                
                                                strongSelf.stack.context.performAndWait {
                                                    do {
                                                        try strongSelf.stack.context.save()
                                                    } catch let error {
                                                        print("error: \(error.localizedDescription)")
                                                        return
                                                    }
                                                }
                                            } catch let error {
                                                print("error: \(error.localizedDescription)")
                                                return
                                            }
                                            
                                            // reload on main
                                            DispatchQueue.main.async {
                                                reloadAlbum()
                                            }
                                        }
            }
        }
        else {
            reloadAlbum()
        }
    }
 
    // handle sharing flick
    @objc func shareFlickBbiPressed(_ sender: UIBarButtonItem) {
 
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
            if let title = pin.title {
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
        
        // test if cell is selected for deletion...show/hide checkmark
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
                cell.activityIndicator.stopAnimating()
            }
        }
        else {
            
            cell.activityIndicator.startAnimating()
            cell.imageView.image = UIImage(named: "DefaultCVCellImage")

            if loadState == FRCProgressStates.doneInserting {
                cell.imageView.transform = .identity
            }
            else {
                cell.imageView.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
                Timer.scheduledTimer(withTimeInterval: 0.1,
                                     repeats: true) {
                                        [weak self] (timer) in
                                        
                                        // 171022, ARC cleanup
                                        guard let strongSelf = self else {
                                            return
                                        }
                                        
                                        if strongSelf.collectionView.indexPathsForVisibleItems.contains(indexPath) {
                                            
                                            let cell = collectionView.cellForItem(at: indexPath) as! PhotoCell
                                            
                                            timer.invalidate()
                                            UIView.animate(withDuration: 0.5,
                                                           animations: {
                                                            
                                                            cell.imageView.transform = .identity
                                            })
                                        }
                }
            }
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
            - If vc in currently in .normal mode, place vc into imagePreview mode when a cell is tapped
            - If in .editing mode, handle selecting/deselecting a cell/flick for deletion
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
    
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        
        // new frc changes..clear array for new completions
        cvBatchCompletionsArray.removeAll(keepingCapacity: false)
        
        if mode == .preDownloading {
            mode = .downloading
            configureBars()
        }
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        
        /*
         handle updates to Pin/Flicks and update UI
        */
        
        switch type {
        case .insert:
            
            loadState = .inserting
            cvBatchCompletionsArray.append {
                // 171022, ARC cleanup
                [weak self] in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.collectionView.insertItems(at: [newIndexPath!])
            }
        case .delete:
            cvBatchCompletionsArray.append {
                // 171022, ARC cleanup
                [weak self] in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.collectionView.deleteItems(at: [indexPath!])
            }
        case .update:
            cvBatchCompletionsArray.append {
                // 171022, ARC cleanup
                [weak self] in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.collectionView.reloadItems(at: [indexPath!])
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

        // fire batch updates
        collectionView.performBatchUpdates({
            
            // 171022, ARC cleanup
            [weak self] in
            guard let strongSelf = self else {
                return
            }
            for op in strongSelf.cvBatchCompletionsArray {
                op()
            }
        })
        
        switch loadState {
        case .inserting:
            loadState = .doneInserting
        default:
            break
        }
        
        if mode == .downloading {
            
            let progress = downloadProgress()
            
            progressView.setProgress(progress, animated: true)
            
            // downloading complete (progress >= 1.0)
            if progress >= albumDownloadComplete {
                
                // return to normal mode
                mode = .normal
                configureBars()
                
                // config scrollView with images
                configureImagePreviewScrollView()
                
                // animate out progressView
                UIView.animate(withDuration: 0.3) {
                    self.progressView.alpha = 0.0
                }
            }
        }
    }
}

// MARK: Helper Functions
extension AlbumViewController {
    
    // return download progress 0.0 -> no downloads yet. 1.0 -> downloads complete
    func downloadProgress() -> Float {
        
        /*
         return download progress.
         progress in non-nil image data count / total count
         used for progressView updates
        */
        
        // verify valid objects, non-zero count
        guard let fetchedObjects = fetchedResultsController.fetchedObjects,
            fetchedObjects.count > 0 else {
                return 0.0
        }
        
        // count non-nil image, sum
        var downloadCount: Float = 0.0
        for flick in fetchedObjects {
            if flick.image != nil {
                downloadCount = downloadCount + 1.0
            }
        }
        
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
        
        // flexBbi...used is various modes below...
        let flexBbi = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)

        // placeholderBbi..used to mask navbar back button..used in various modes below
        let placeholdeBbi = UIBarButtonItem(title: "",
                                            style: .plain,
                                            target: nil,
                                            action: nil)
        
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
            navigationItem.setLeftBarButton(nil, animated: true)
            navigationItem.setRightBarButton(nil, animated: true)
            break
        case .downloading:
            /*
             Downloading mode. VC is currently in the process of downloading flicks.
             */
            
            // hide activityView in middle of CV....default cells now have activityViews
            activityIndicator.isHidden = true
            activityIndicator.stopAnimating()
            
            // show progressView..with current download progress
            let progress = downloadProgress()
            progressView?.progress = progress

            // show progressView
            progressView.alpha = 1.0
            
            // nil all bbi's on bars
            setToolbarItems(nil, animated: true)
            navigationItem.setLeftBarButton(nil, animated: true)
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
            
            navigationItem.setLeftBarButton(nil, animated: true)
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
            
            // hide back button..
            navigationItem.setLeftBarButton(placeholdeBbi, animated: true)
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
            
            // hide back button..
            navigationItem.setLeftBarButton(placeholdeBbi, animated: true)
        case .noFlicksFound:
            /*
             No flicks were found for Pin
            */
            
            // no bbi's. Show NoFlicksFound image
            navigationItem.setLeftBarButton(nil, animated: true)
            navigationItem.setRightBarButton(nil, animated: true)
            setToolbarItems(nil, animated: true)
            noFlicksImageView.image = UIImage(named: "NoFlicksFound")
            noFlicksImageView.isHidden = false
        }
    }
}
