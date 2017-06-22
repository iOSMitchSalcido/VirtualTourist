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

    @IBOutlet weak var mapView: MKMapView!  // ref to mapView
    
    var stack: CoreDataStack!
    var context: NSManagedObjectContext!    // ref to managedObjectContext
    
    let SEARCH_RADIUS: Double = 10.0    // default search radius
    
    // core data stack
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // retrieve stack/context
        stack = CoreDataStack("VirtualTouristModel")
        context = stack.context
        
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
            print("unable to fetch Pins")
        }
        
        // add annotations to mapView
        mapView.addAnnotations(annotations)
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
                
                // valid placemark info..continue and create an annot for mapView
                
                // sift placemark info for pertinent annot title
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
                
                self.stack.container.performBackgroundTask() { (privateContext) in
                    
                    // coordinate
                    let newCoord = Coordinate(context: privateContext)
                    newCoord.latitude = Double(coord.latitude)
                    newCoord.longitude = Double(coord.longitude)
                    
                    // Pin
                    let newPin = Pin(context: privateContext)
                    newPin.coordinate = newCoord
                    newPin.title = locationTitle
                    
                    do {
                        try privateContext.save()
                        
                        // create/config annot, add to mapView
                        let annot = VTAnnotation()
                        annot.coordinate = coord
                        annot.title = locationTitle
                        annot.pin = (self.context.object(with: newPin.objectID) as! Pin)
                        
                        DispatchQueue.main.async {
                            self.mapView.addAnnotation(annot)
                        }
                    } catch {
                        print("error saving private context")
                    }
                }
            }
        default:
            break
        }
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
                
                self.stack.container.performBackgroundTask() { (privateContext) in

                    let privatePin = privateContext.object(with: pin.objectID) as! Pin
                    privateContext.delete(privatePin)
                    do {
                        try privateContext.save()
                        print("saving private context")
                    } catch {
                        print("unable to save private context")
                    }
                }
            }
        }
        // right accessory. Retrieve flicks and navigate to PhotosCVC
        else if control == view.rightCalloutAccessoryView {
            
            let controller = storyboard?.instantiateViewController(withIdentifier: "PhotosCollectionViewControllerID") as! PhotosCollectionViewController
            controller.pin = pin
            controller.context = context
            controller.stack = stack
            navigationController?.pushViewController(controller, animated: true)

            // no flicks in Pin
            if let count = pin.flicks?.count, count == 0 {
                
                let lon = Double(annotation.coordinate.longitude)
                let lat = Double(annotation.coordinate.latitude)
                let radius = SEARCH_RADIUS
                let geo = (lon, lat, radius)

                let flickr = FlickrAPI()
                flickr.flickSearchforText(nil, geo: geo) {
                    (data, error) in
                    
                    guard let data = data else {
                        return
                    }
                    
                    guard let photosDict = data["photos"] as? [String: AnyObject],
                        let photosArray = photosDict["photo"] as? [[String: AnyObject]] else {
                            return
                    }
                    
                    var urlStringArray = [String]()
                    for dict in photosArray {
                        if let urlString = dict["url_m"] as? String {
                            urlStringArray.append(urlString)
                        }
                    }
                    
                    self.stack.container.performBackgroundTask() {
                        (privateContext) in
                        
                        let pin = privateContext.object(with: pin.objectID) as! Pin
                        for string in urlStringArray {
                            let flick = Flick(context: privateContext)
                            flick.urlString = string
                            pin.addToFlicks(flick)
                        }
                        
                        do {
                            try privateContext.save()
                        } catch {
                        }
                    }
                }
            }
        }
    }
}

extension MapViewController {
    
    func saveContext() {
        do {
            try context.save()
        } catch {
            print("unable to save context")
        }
    }
}
