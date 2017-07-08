//
//  MapViewController.swift
//  VirtualTourist
//
//  Created by Online Training on 6/14/17.
//  Copyright © 2017 Mitch Salcido. All rights reserved.
//
/*
 About MapViewController.swift:
 */

import UIKit
import MapKit
import CoreData

class MapViewController: UIViewController {

    // constants
    let USER_LOCATION_KmACCURACY: CLLocationAccuracy = 5.0  // user location, Km accuracy
    let USER_SPAN_DEGREES: CLLocationDegrees = 0.3          // user location span
    
    // view objects
    @IBOutlet weak var mapView: MKMapView!          // ref to mapView
    @IBOutlet weak var titleImageView: UIImageView! // ref to nav titleImageView
    
    // CoreData
    var stack: CoreDataStack!               // ref to CoreDataStack
    var context: NSManagedObjectContext!    // ref to managedObjectContext
    
    // ref to search bbi
    var searchBbi: UIBarButtonItem!
    
    // location manager
    var locationManager: CLLocationManager!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // titleView
        titleImageView.image = UIImage(named: "MapNavTitleImage")

        // retrieve stack/context
        stack = CoreDataStack("VirtualTouristModel")
        context = stack.context
        
        // core location. Determine auth..request auth
        // .. searchBbi creation is handled in coreLocation delegate
        let coreLocationAuthStatus = CLLocationManager.authorizationStatus()
        locationManager = CLLocationManager()
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer * USER_LOCATION_KmACCURACY
        locationManager.distanceFilter = kCLLocationAccuracyKilometer * USER_LOCATION_KmACCURACY
        locationManager.delegate = self

        // test location auth status
        switch coreLocationAuthStatus {
        case .notDetermined:
            // not determined...request auth
            locationManager.requestWhenInUseAuthorization()
        default:
            break
        }
        
        /*
         do a fetch to populate map with pins. Create a fetch request and an empty annotations array.
         Iterate through fetch results using attribs to populate properties in MKPoint annotation.
         This annotation is then added to the annotations array, which is then added to the
         mapView annotations
        */
        
        let flickFr: NSFetchRequest<Flick> = Flick.fetchRequest()
        do {
            let flicksResults = try context.fetch(flickFr)
            
            for flick in  flicksResults {
                if flick.pin == nil {
                    print("unowned flick")
                }
            }
        } catch {
            //TODO: error handling
        }
        
        // array to hold annotations
        var annotations = [VTAnnotation]()

        // fetch request
        let request: NSFetchRequest<Pin> = Pin.fetchRequest()
        do {
            // perform fetch
            let results = try context.fetch(request)
            
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
            }
        } catch {
            //TODO: error handling
        }
        
        // add annotations to mapView
        mapView.addAnnotations(annotations)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        navigationController?.setToolbarHidden(true, animated: true)
    }
    
    // long press GR
    @IBAction func longPressDetected(_ sender: UILongPressGestureRecognizer) {
        
        /*
         Handle long press GR. This function handles the detection of a long press. The touch point is identified
         in the mapView into a coord. This coord is then used to geocode a placemark for location identification.
         
         Upon successful reverse geocoding of touchpoint, an annot is added to mapView.
        */
        
        switch sender.state {
        case .began:
            print("longPressBegan")
            // begin long press detection
            
            // get touch point and coord in mapView
            let touchPoint = sender.location(in: mapView)
            let coord = mapView.convert(touchPoint, toCoordinateFrom: mapView)

            // reverse geocode coord
            let location = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
            let geoCoder = CLGeocoder()
            geoCoder.reverseGeocodeLocation(location) {
                (placemarks, error) in
                
                // test for geocode errors...look at most pertinent errors
                if let error = error as? CLError.Code {
                    
                    // error...present in alert with message
                    switch error {
                    case .locationUnknown:
                        self.presentAlertForError(VTError.locationError("Unknown location"))
                    case .network:
                        self.presentAlertForError(VTError.locationError("Network unavailable"))
                    case .geocodeFoundNoResult:
                        self.presentAlertForError(VTError.locationError("Geocode yielded no result"))
                    default:
                        self.presentAlertForError(VTError.locationError("Unknown geocoding error"))
                    }
                    return
                }
                
                // test for valid placemark found in reverse geocoding
                guard let placemark = placemarks?.first else {
                    self.presentAlertForError(VTError.locationError("Geocoding error. Possible network issue or offline"))
                    return
                }
                
                // valid placemark info.. continue and create an annot for mapView
                
                // sift placemark info for pertinent annot title..default title is "Location"
                var locationTitle = "Location"
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
                
                // create coordinate MO
                let newCoord = Coordinate(context: self.context)
                newCoord.latitude = Double(coord.latitude)
                newCoord.longitude = Double(coord.longitude)
                
                // create Pin MO
                let newPin = Pin(context: self.context)
                newPin.coordinate = newCoord
                newPin.title = locationTitle
                
                do {
                    try self.context.save()
                    
                    // create/config annot, add to mapView
                    let annot = VTAnnotation()
                    annot.coordinate = coord
                    annot.title = locationTitle
                    annot.pin = newPin
                    DispatchQueue.main.async {
                        self.mapView.addAnnotation(annot)
                    }
                    
                    let flickr = FlickrAPI()
                    flickr.createFlickrAlbumForPinZ(newPin) {
                        (data, error) in
                        
                        guard error == nil else {
                            print(error!)
                            return
                        }
                        
                        guard let data = data else {
                            print("bad array")
                            return
                        }
                        
                        let privateContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
                        privateContext.parent = self.context
                        
                        print("good array")
                        
                        privateContext.perform {
                            
                            let pin = privateContext.object(with: newPin.objectID) as! Pin
                            
                            for urlString in data {
                                let flick = Flick(context: privateContext)
                                flick.urlString = urlString
                                pin.addToFlicks(flick)
                                
                                do {
                                    try privateContext.save()
                                    
                                    self.context.performAndWait {
                                        do {
                                            try self.context.save()
                                        } catch {
                                            
                                        }
                                    }
                                } catch {
                                    
                                }
                            }
                            
                            let request: NSFetchRequest<Flick> = Flick.fetchRequest()
                            let sort = NSSortDescriptor(key: #keyPath(Flick.urlString), ascending: true)
                            let predicate = NSPredicate(format: "pin == %@", pin)
                            request.predicate = predicate
                            request.sortDescriptors = [sort]
                            do {
                                let objects = try privateContext.fetch(request)
                                
                                for flick in objects {
                                    
                                    if let urlString = flick.urlString,
                                    let url = URL(string: urlString),
                                        let imageData = NSData(contentsOf: url) {
                                        
                                        flick.image = imageData
                                        
                                        do {
                                            try privateContext.save()
                                            
                                            self.context.performAndWait {
                                                do {
                                                    try self.context.save()
                                                } catch {
                                                    
                                                }
                                            }
                                        } catch {
                                        }
                                    }
                                }
                            } catch {
                            }
                        }
                    }
                } catch {
                    //TODO: error handling
                    print("bad context save during new Pin creation")
                }
            }
        default:
            break
        }
    }
    
    func searchBbiPressed(_ sender: UIBarButtonItem) {
        
        // Request a location
        locationManager.requestLocation()
    }
    
    // handle segue prep
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        guard segue.identifier == "AlbumSegueID" else {
            return
        }
        // set pin and core data in destination controller
        let controller = segue.destination as! AlbumViewController
        controller.stack = stack
        controller.context = context
        controller.pin = sender as! Pin
    }
}

// mapView delegate functions
extension MapViewController: MKMapViewDelegate {
    
    // annotationView
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        
        // dequeue view
        let reuseId = "pin"
        var pinView = mapView.dequeueReusableAnnotationView(withIdentifier: reuseId) as? MKPinAnnotationView
        
        // create view if nil
        if pinView == nil {
            
            // create and config pinView
            pinView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: reuseId)
            pinView!.canShowCallout = true
            pinView!.pinTintColor = .green
            pinView?.animatesDrop = true
            pinView?.isDraggable = true
            
            // add right callout..used to prompt user to Flicks CVC
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
        else {
            pinView!.annotation = annotation
        }
        pinView!.annotation = annotation

        return pinView
    }
    
    // accessory tap
    func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
        
        // test for annotation and Pin
        guard let annotation = view.annotation as? VTAnnotation,
            let pin = annotation.pin else {
                return
        }
        
        // left accessory. Delete Pin and Flick album
        if control == view.leftCalloutAccessoryView {
            
            // create proceed/cancel alert to handle deleting location
            presentProceedCancelAlert(title: "Delete Location ?", message: "Delete location and Flick's") {
                (action) in
                
                // remove pin from map
                mapView.removeAnnotation(annotation)
                annotation.pin = nil

                self.stack.container.performBackgroundTask() { (privateContext) in
                    
                    // !! inconsistant Pin deletion unless merge policy is set
                    privateContext.mergePolicy = NSMergePolicy.overwrite
                    
                    let privatePin = privateContext.object(with: pin.objectID) as! Pin
                    privateContext.delete(privatePin)
                    do {
                        
                        if privateContext.hasChanges {
                            try privateContext.save()
                        }
                        print("delete Pin MapView - good save 😇😇😇")
                    } catch {
                        //TODO: error handling
                        print("delete Pin MapView - bad save 😡😡😡")
                    }
                }
            }
        }
        // right accessory. Navigate to AlbumVC
        else if control == view.rightCalloutAccessoryView {
            performSegue(withIdentifier: "AlbumSegueID", sender: pin)
        }
    }
}

extension MapViewController: CLLocationManagerDelegate {
    
    // handle user location update
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        
        // test for valid location
        guard let location = locations.last else {
            return
        }
        
        // zoom in to user location
        let coordinate = location.coordinate
        let span = MKCoordinateSpan(latitudeDelta: USER_SPAN_DEGREES,
                                    longitudeDelta: USER_SPAN_DEGREES)
        let region = MKCoordinateRegion(center: coordinate, span: span)
        mapView.setRegion(region, animated: true)
    }
    
    // user location error
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        
        // location error. Show alert
        presentAlertForError(VTError.locationError("User location search failure."))
    }
    
    // handle CL auth
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        
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
