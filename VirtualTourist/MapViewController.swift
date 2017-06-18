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

    @IBOutlet weak var mapView: MKMapView!      // ref to mapView
    
    // context
    var context: NSManagedObjectContext!
    
    // core data stack
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // retrieve context
        context = CoreDataStack("VirtualTouristModel").context
        
        /*
         do a fetch to populate map with pins. Create a fetch request and an empty annotations array.
         Iterate through fetch results using attribs to populate properties in MKPoint annotation.
         This annotation is then added to the annotations array, which is then added to the
         mapView annotations
        */
        
        // array to hold annotations
        var annotations = [MKPointAnnotation]()

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
                    let annot = MKPointAnnotation()
                    annot.title = pin.title
                    annot.coordinate = CLLocationCoordinate2D(latitude: lat,
                                                              longitude: lon)
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
                
                // create/config annot, add to mapView
                let annot = MKPointAnnotation()
                annot.coordinate = coord
                annot.title = locationTitle
                self.mapView.addAnnotation(annot)
                
                // add to context
                
                // coordinate
                let newCoord = Coordinate(context: self.context)
                newCoord.latitude = Double(coord.latitude)
                newCoord.longitude = Double(coord.longitude)
                
                // Pin
                let newPin = Pin(context: self.context)
                newPin.coordinate = newCoord
                newPin.title = locationTitle
                
                // save
                do {
                    try self.context.save()
                    print("good save")
                } catch {
                    print("unable to save context")
                }
            }
        default:
            break
        }
    }
    
    // segue prep
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        guard segue.identifier == "PCVCSegueID",
            let annotationView = sender as? MKAnnotationView,
            let annot = annotationView.annotation else {
                return
        }
        
        let controller = segue.destination as! PhotosCollectionViewController
        controller.title = annot.title!
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
        
        if control == view.leftCalloutAccessoryView {
            
            // create an proceed/cancel alert to handle deleting location
            presentProceedCancelAlert(title: "Delete Location ?", message: "Delete location and Flick's") {
                (action) in
                
                guard let annotation = view.annotation else {
                    return
                }
                mapView.removeAnnotation(annotation)
            }
        }
        else if control == view.rightCalloutAccessoryView {

            let lon = Double((view.annotation?.coordinate.longitude)!)
            let lat = Double((view.annotation?.coordinate.latitude)!)
            let radius = Double(10.0)
            
            let flickr = FlickrAPI()
            flickr.flickSearchforText(nil, geo: (lon, lat, radius)) {
                (data, error) in
                
                guard error == nil else {
                    print("error during flickr")
                    return
                }
                
                guard let data = data,
                    let photos = data["photos"] as? [String:AnyObject],
                    let photoArray = photos["photo"] as? [[String:AnyObject]] else {
                        print("bad data returned")
                        return
                }
                
                var urlArray = [String]()
                for photo in photoArray {
                    if let urlString = photo["url_m"] as? String {
                        urlArray.append(urlString)
                    }
                }
                
                let controller = self.storyboard?.instantiateViewController(withIdentifier: "PhotosCollectionViewControllerID") as! PhotosCollectionViewController
                controller.photoURLString = urlArray
                
                // set view title
                if let locationTitle = view.annotation?.title {
                    controller.title = locationTitle
                }
                else {
                    controller.title = "Location"
                }
                
                DispatchQueue.main.async {
                    self.navigationController?.pushViewController(controller, animated: true)
                }
            }
        }
    }
}
