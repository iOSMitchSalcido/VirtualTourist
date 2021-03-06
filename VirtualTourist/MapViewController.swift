//
//  MapViewController.swift
//  VirtualTourist
//
//  Created by Online Training on 6/14/17.
//  Copyright © 2017 Mitch Salcido. All rights reserved.
//
/*
 About MapViewController.swift:
 Handle presentation and placement of drop pins on map.
 
 - MapView for canvas to place pins on
 - Core Data for persisting pins
 - Location manager allows user to locate and zoom in on their present location
 - Long press gesture recognizer for dropping a new pin on map
 - Left/right accessories on pin callout allows user to either delete pin or navigate into AlbumVC for flick viewing
 */

import UIKit
import MapKit
import CoreData

class MapViewController: UIViewController {

    // constants
    let userLocationAccuracyKm: CLLocationAccuracy = 5.0    // user location, Km accuracy
    let userSpanDegrees: CLLocationDegrees = 0.3            // user location span
    
    // constant for default location name in event that placemark can't determine location
    // during reverse geocode.
    let defaultLocationTitle = "Location"
    
    // view objects
    @IBOutlet weak var mapView: MKMapView!          // ref to mapView
    @IBOutlet weak var titleImageView: UIImageView! // ref to nav titleImageView
    
    // CoreData stack
    var stack: CoreDataStack!
    
    // ref to search bbi. Zoom to user's current location when pressed
    var searchBbi: UIBarButtonItem!
    
    // location manager. Used to determine user's location
    var locationManager: CLLocationManager!
    
    // ref for tracking/dragging Pin that was just placed
    var dragPin: VTAnnotation?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // titleView
        titleImageView.image = UIImage(named: "MapNavTitleImage")

        // retrieve stack/context
        stack = CoreDataStack("VirtualTouristModel")
        
        // core location. Determine auth..request auth
        // .. searchBbi creation is handled in coreLocation delegate
        let coreLocationAuthStatus = CLLocationManager.authorizationStatus()
        locationManager = CLLocationManager()
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer * userLocationAccuracyKm
        locationManager.distanceFilter = kCLLocationAccuracyKilometer * userLocationAccuracyKm
        locationManager.delegate = self

        // test location auth status
        switch coreLocationAuthStatus {
        case .notDetermined:
            // not determined...request auth
            locationManager.requestWhenInUseAuthorization()
        default:
            break
        }
        
        // add appInfo bbi
        let infoButton = UIButton(type: .infoLight)
        infoButton.addTarget(self, action: #selector(appInfoBbiPressed), for: .touchUpInside)
        navigationItem.leftBarButtonItem = UIBarButtonItem(customView: infoButton)
        
        // debug code ...looking for unowned flicks
        let flickFr: NSFetchRequest<Flick> = Flick.fetchRequest()
        do {
            let flicksResults = try stack.context.fetch(flickFr)
            
            for flick in  flicksResults {
                if flick.pin == nil {
                    print("unowned flick")
                }
            }
        } catch {
        }
        
        /*
         do a fetch to populate map with pins. Create a fetch request and an empty annotations array.
         Iterate through fetch results using attribs to populate properties in MKPoint annotation.
         This annotation is then added to the annotations array, which is then added to the
         mapView annotations
         */
        
        // array to hold annotations
        var annotations = [VTAnnotation]()

        // fetch request
        let request: NSFetchRequest<Pin> = Pin.fetchRequest()
        do {
            // perform fetch
            let results = try stack.context.fetch(request)
            
            // iterate through results
            for pin in results {
                
                // test coordinate
                if let lat = pin.coordinate?.latitude,
                    let lon = pin.coordinate?.longitude {
                    
                    // create annotation and append to annotations
                    let coord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                    let annot = VTAnnotation()
                    annot.coordinate = coord
                    annot.title = pin.title
                    annot.pin = pin
                    annotations.append(annot)
                }
                
                // test if flicks have been fully downloaded for pin..resume if still some nil flicks
                if !pin.downloadComplete {
                    resumeAlbumDownloadForPin(pin, stack: stack)
                }
            }
        } catch {
            // fetch error
            presentAlertForLocalizedError(CoreDataError.fetch("Unable to fetch saved Pins."))
            return
        }
        
        // add annotations to mapView
        mapView.addAnnotations(annotations)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // hide toolbar
        navigationController?.setToolbarHidden(true, animated: true)
    }
    
    // long press GR
    @IBAction func longPressDetected(_ sender: UILongPressGestureRecognizer) {
        
        /*
         Action for long press gesture.
         Handle new pin placement and also pin dragging. Pin is placed on beginning of gesture. If user
         drags pin, then .change updates postion of pin by using a reference to the annotation. At end
         of gesture, Pin MO is created and assigned to annot.
        */
        
        // get pin coordinate
        let touchPoint = sender.location(in: mapView)
        let coordinate = mapView.convert(touchPoint, toCoordinateFrom: mapView)
        
        switch sender.state {
        case .began:
            // create/config annot, add to mapView
            let annot = VTAnnotation()
            annot.coordinate = coordinate
            mapView.addAnnotation(annot)
            
            // ref to annot..used for dragging
            dragPin = annot
        case .changed:
            
            // annot has been dragged, update location of annot
            if let _ = dragPin {
                dragPin?.coordinate = coordinate
            }
        case .ended:
            
            // done. assign Pin to annot
            if let _ = dragPin {
                dragPin?.coordinate = coordinate
                assignPinToAnnotation(dragPin!)
                dragPin = nil
            }
        default:
            break
        }
    }
    
    // infoBbi pressed
    @objc func appInfoBbiPressed () {
        
        /*
         Invoke AppHelpVC
         */
        
        let controller = storyboard?.instantiateViewController(withIdentifier: "HelpNavViewControllerID") as! UINavigationController
        present(controller, animated: true)
    }
    
    @objc func searchBbiPressed(_ sender: UIBarButtonItem) {
        
        /*
         Invoke location request from location manager...delegate method handles zooming to user location.
        */
        
        locationManager.requestLocation()
    }
    
    // handle segue prep
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        /*
         Right accessory on pin callout was tapped... handle configuring AlbumVC
        */
        
        // segue to AlbumVC
        guard segue.identifier == "AlbumSegueID",
            let annotation = sender as? VTAnnotation,
            let pin = annotation.pin else {
                return
        }
        
        // set pin and core data in destination controller
        let controller = segue.destination as! AlbumViewController
        controller.stack = stack
        controller.pin = pin
    }
}

// mapView delegate functions
extension MapViewController: MKMapViewDelegate {
    
    // annotationView
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        
        /*
         AnnotView for annot.
         Handle creation of pin annot view. Includes pin location title, and accessories on left/right
         to invoke Pin deletion or navigation to AlbumVC for viewing flicks
        */
        
        // dequeue pin annot view
        let reuseId = "pin"
        var pinView = mapView.dequeueReusableAnnotationView(withIdentifier: reuseId) as? MKPinAnnotationView
        
        // create view if nil
        if pinView == nil {
            
            // create and config pinView
            pinView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: reuseId)
            pinView!.canShowCallout = true
            pinView!.pinTintColor = .green
            pinView?.animatesDrop = true
            
            // add right callout..used to prompt user to navigate to AlbumVC
            let rightCalloutAccessoryView = UIButton(type: .custom)
            rightCalloutAccessoryView.frame = CGRect(x: 0.0, y: 0.0, width: 33.0, height: 33.0)
            let rightImage = UIImage(named: "RightCalloutAccessoryImage")
            rightCalloutAccessoryView.setImage(rightImage, for: .normal)
            pinView?.rightCalloutAccessoryView = rightCalloutAccessoryView
            
            // add left callout...used to prompt user to delete pin
            let leftCalloutAccessoryView = UIButton(type: .custom)
            leftCalloutAccessoryView.frame = CGRect(x: 0.0, y: 0.0, width: 22.0, height: 22.0)
            let leftImage = UIImage(named: "LeftCalloutAccessoryImage")
            leftCalloutAccessoryView.setImage(leftImage, for: .normal)
            pinView?.leftCalloutAccessoryView = leftCalloutAccessoryView
        }

        // assign annot to view
        pinView!.annotation = annotation

        return pinView
    }
    
    // accessory tap
    func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
        
        /*
         callout accessory tapped
         Handle Pin deletion if left accessory tapped.
         Navigate into AlbumVC if right accessory tapped.
         */
        
        // test for annotation and Pin
        guard let annotation = view.annotation as? VTAnnotation,
            let pin = annotation.pin else {
                return
        }
        
        // left accessory. Delete Pin
        if control == view.leftCalloutAccessoryView {
            
            // remove pin from map
            mapView.removeAnnotation(annotation)
            annotation.pin = nil
            
            // perform on private context/queue
            let privateContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
            privateContext.parent = self.stack.context
            privateContext.perform {
                
                // 171022, ARC cleanup
                [weak self] in
                guard let strongSelf = self else {
                    return
                }
                
                let privatePin = privateContext.object(with: pin.objectID) as! Pin
                privateContext.delete(privatePin)
                
                // save
                let _ = strongSelf.stack.savePrivateContext(privateContext)
            }
        }
        // right accessory. Navigate to AlbumVC
        else if control == view.rightCalloutAccessoryView {
            performSegue(withIdentifier: "AlbumSegueID", sender: annotation)
        }
    }
}

// location manager delegate methods
extension MapViewController: CLLocationManagerDelegate {
    
    // handle user location update
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        
        /*
         response to user pressing search bbi to locate their position on map.
        */
        
        // test for valid location
        guard let location = locations.last else {
            return
        }
        
        // zoom in to user location
        let coordinate = location.coordinate
        let span = MKCoordinateSpan(latitudeDelta: userSpanDegrees,
                                    longitudeDelta: userSpanDegrees)
        let region = MKCoordinateRegion(center: coordinate, span: span)
        mapView.setRegion(region, animated: true)
    }
    
    // user location error
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        
        // location error. Show alert
        presentAlertForLocalizedError(LocationError.location("Failure finding user location."))
    }
    
    // handle CL auth
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        
        /*
         location services authorization. If auth good, place search bbi on right navbar that allows
         user to zoom in on their current location.
        */
        
        // test status
        switch status {
        case .authorizedWhenInUse:
            // search bbi..used to zoom in to user location
            searchBbi = UIBarButtonItem(barButtonSystemItem: .search,
                                        target: self,
                                        action: #selector(searchBbiPressed(_:)))
            navigationItem.rightBarButtonItem = searchBbi
        default:
            break
        }
    }
}

// helper functions
extension MapViewController {
    
    // assign a Pin to annotation
    func assignPinToAnnotation(_ annotation: VTAnnotation) {
        
        /*
         Handle creation of a Pin MO to attached to an annotation.
         Perform reverse geocode on annot coordinates, looking for valid placemark data. The location
         info (name/title of location, state, name of city, etc) retrieved from the placemark. This
         is used to set the title in the newly created Pin MO.
         
         ...an album is then downloaded for the Pin
        */
        
        // pull coordinate from annotation
        let coordinate = annotation.coordinate
        
        // reverse geocode coord
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let geoCoder = CLGeocoder()
        geoCoder.reverseGeocodeLocation(location) {
            [weak self] (placemarks, error) in
            
            guard let strongSelf = self else {
                return
            }
            
            // test for geocode errors...look at most pertinent errors
            if let error = error as? CLError.Code {
                
                // error...present in alert with message and  remove annot pin from map
                switch error {
                case .locationUnknown:
                    strongSelf.presentAlertForLocalizedError(LocationError.location("Unknown location."))
                case .network:
                    strongSelf.presentAlertForLocalizedError(LocationError.status("Location network unavailable."))
                case .geocodeFoundNoResult:
                    strongSelf.presentAlertForLocalizedError(LocationError.location("Geocode yielded no result."))
                default:
                    strongSelf.presentAlertForLocalizedError(LocationError.status("Unknown geocoding error."))
                }
                
                // remove annotation...unusable location
                strongSelf.mapView.removeAnnotation(annotation)
                
                return
            }
            
            // set default location title, then test for valid placemark data for use as title
            var locationTitle = strongSelf.defaultLocationTitle
            if let placemark = placemarks?.first {
             
                if let locality = placemark.locality {
                    locationTitle = locality
                }
                else if let administrativeArea = placemark.administrativeArea {
                    locationTitle = administrativeArea
                }
                else if let country = placemark.country {
                    locationTitle = country
                }
                else if let ocean = placemark.ocean {
                    locationTitle = ocean
                }
            }
            
            // perform pin creation on private queue/context
            let privateContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
            privateContext.parent = strongSelf.stack.context
            privateContext.perform {
                
                // create coordinate MO
                let newCoord = Coordinate(context: privateContext)
                newCoord.latitude = Double(coordinate.latitude)
                newCoord.longitude = Double(coordinate.longitude)
                
                // create Pin MO, config Pin and annot
                let pin = Pin(context: privateContext)
                pin.coordinate = newCoord
                pin.title = locationTitle
                
                // test for good save
                if !strongSelf.stack.savePrivateContext(privateContext) {
                    
                    // bad save, remove annotation and show alert
                    DispatchQueue.main.async {
                        strongSelf.mapView.removeAnnotation(annotation)
                        strongSelf.presentAlertForLocalizedError(CoreDataError.save("Error saving new Pin."))
                    }
                }
                else {
                    
                    // good save. Proceed to assign pin to annotaions, begin album download
                    DispatchQueue.main.async {
                        let pin = strongSelf.stack.context.object(with: pin.objectID) as! Pin
                        annotation.title = locationTitle
                        annotation.pin = pin;
                        strongSelf.downloadAlbumForPin(pin, stack: strongSelf.stack)
                    }
                }
            }
        }
    }
}
