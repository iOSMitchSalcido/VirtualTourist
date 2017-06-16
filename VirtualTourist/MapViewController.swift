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

class MapViewController: UIViewController {

    @IBOutlet weak var mapView: MKMapView!      // ref to mapView
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    // long press GR
    @IBAction func longPressDetected(_ sender: UILongPressGestureRecognizer) {
        
        /*
         Handle long press GR. This function handles the detection of a long press. The touch point is identified
         in the mapView into a coord. This coord is then used to geocode a placemark for location identification.
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
                    default:
                        self.presentAlertForError(VTError.locationError("Geocoding error"))
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
            }
        default:
            break
        }
    }
}

extension MapViewController: MKMapViewDelegate {
    
    // annotationView
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        
        // dequeue view
        let reuseId = "pin"
        var pinView = mapView.dequeueReusableAnnotationView(withIdentifier: reuseId) as? MKPinAnnotationView
        
        // create view if nil
        if pinView == nil {
            pinView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: reuseId)
            pinView!.canShowCallout = true
            pinView!.pinTintColor = .green
            pinView!.rightCalloutAccessoryView = UIButton(type: .detailDisclosure)
            let leftCalloutAccessoryView = UIButton(type: .roundedRect)
            leftCalloutAccessoryView.frame = CGRect(x: 0.0, y: 0.0, width: 55.0, height: 35.0)
            leftCalloutAccessoryView.setTitle("Delete", for: .normal)
            pinView?.leftCalloutAccessoryView = leftCalloutAccessoryView
        }
        else {
            pinView!.annotation = annotation
        }
        
        pinView?.animatesDrop = true
        
        return pinView
    }
    
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
        }
    }
}
