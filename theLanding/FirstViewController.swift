//
//  FirstViewController.swift
//  theLanding
//
//  Created by Seth Childers on 2/4/19.
//  Copyright © 2019 Seth Childers. All rights reserved.
//

import UIKit
import MapKit
import Firebase
import FirebaseFirestore
import CoreLocation

class FirstViewController: UIViewController, CLLocationManagerDelegate {
    
    // location manager
    var locationManager:CLLocationManager!
    // user location
    var userLocation:CLLocation!
    // distance to next stop
    var metersToShuttleStop: [CLLocationDistance]!
    // closest stop to the users current location
    var closestLocation: (name: String, location: CLLocation, distance: Double)!
    // walking time in minutes to closest shuttle stop
    var travelTime: Double!
    // the shuttle schedule
    var schedule: [String]!
    // the map
    @IBOutlet weak var mapView: MKMapView!
    // the display time for next suggested shuttle time
    @IBOutlet weak var displayTime: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // setup the firebase instance
        let db = Firestore.firestore()
        let settings = db.settings
        settings.areTimestampsInSnapshotsEnabled = true
        db.settings = settings

        // get the next shuttle time
        displayTime.font = displayTime.font.withSize(25)
        displayTime.text = "Calculating... 🤓"
        updateTime()
        getFirebaseData(db: db)
        findCurrentLocation()
    }
    
    // This is messy. Get the schedule and locations from Firebase
    // Then modify the retreived data to be in the format you need
    // Assign the member variable 'schedule' to the modified retreived data
    // Change the displayTime text in the UI
    func getFirebaseData(db: Firestore) {
        
        DispatchQueue.global().async {
            db.collection("locations").getDocuments { (querySnapshot, error) in
                var myTimes: [String] = []
                if let error = error {
                    print("Error getting documents: \(error)")
                } else {
                    for document in querySnapshot!.documents {
                        let locationTimes = document.data()
                        for times in locationTimes {
                            for time in times.value as! [String] {
                                myTimes.append(time)
                            }
                        }
                    }
                    DispatchQueue.main.async {
                        self.schedule = myTimes
//                        print("myTimes1: \(myTimes[0])")
//                        self.displayTime.text = self.schedule[0]
                    }
                }
            }
        }
    }

    // Time updating and formatting. You may want to do this Asynchronously
    func updateTime() {
        let date = Date()
        let calendar = Calendar.current
        let currentHour = calendar.component(.hour, from: date)
        let currentMinutes = calendar.component(.minute, from: date)
        var postfix = "am"
        if (currentHour > 12) {
            postfix = "pm"
        }
        displayTime.font = displayTime.font.withSize(45)
        displayTime.text = "\(currentHour > 12 ? currentHour-12 : currentHour):\(currentMinutes) \(postfix)"
    }

    // Bro Barney - Find the user's current location
    func findCurrentLocation() {
        locationManager = CLLocationManager()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestAlwaysAuthorization()

        if CLLocationManager.locationServicesEnabled() {
            locationManager.startUpdatingLocation()
        }
    }
    
    // Bro Barney - If getting the user's location is successful
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // set the member variable to the most recent location
        userLocation = locations[0] as CLLocation
        // manager.stopUpdatingLocation()
        
        // setup the map with the center being on the user's location
        let center = CLLocationCoordinate2D(latitude: userLocation.coordinate.latitude, longitude: userLocation.coordinate.longitude)
        let region = MKCoordinateRegion(center: center, span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
        mapView.mapType = .satellite
        mapView.setRegion(region, animated: true)
        mapView.showsUserLocation = true
        
        // after getting the user's location, find the closest shuttle stop to them
        getClosestLocation()
    }
    
    // Bro Barney - If getting the user's location is NOT unsuccessful
    private func locationManger(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Error \(error)")
    }
    
    // loop throught the locations and find the closest one to the user
    func getClosestLocation() {
        // we'll need to put these in firebase
        let locations = [
            ("MC", CLLocation.init(latitude: 43.817830, longitude: -111.784218)),
            ("Landing", CLLocation.init(latitude: 43.817204, longitude: -111.794373)),
            ("LLot", CLLocation.init(latitude: 43.811734, longitude: -111.782626)),
            ("Romney", CLLocation.init(latitude: 43.820142, longitude: -111.784076)),
            ("Walmart", CLLocation.init(latitude: 43.8560, longitude: -111.7739)),
            ("Broulims", CLLocation.init(latitude: 43.827012, longitude: -111.787335)),
        ]
        
        DispatchQueue.global().async {
            // first make a random location that is far, far away
            var tempClosest = ("No where", CLLocation.init(latitude: 24.8560, longitude: -12.7739), 1000000000.00)
            for shuttleStop in locations {
                // calculate the distance to the shuttle location from the user's current location
                let distance = [(self.userLocation? .distance(from: shuttleStop.1))!]
                // if the location being checked is closer, assign it as the closest
                if (distance[0] < tempClosest.2) {
                    // (shuttle stop name, coordinates of the stop, how far to the stop)
                    tempClosest = (shuttleStop.0, shuttleStop.1, distance[0])
                }
            }
//            DispatchQueue.main.async {
                // set the member variable
                self.closestLocation = tempClosest
                print(self.closestLocation)
                // after finding the closest location, calculate walking time
                self.getWalkingTime()
//            }
        }
    }
    
    /* These next to methods are dependent on each other. Code them carefully. */
    
    // Based on the users location, calculate the walking time to the closest shuttle stop.
    func getWalkingTime() {
        // set the source and destination coordinates
        let sourceCoordinates = CLLocationCoordinate2D(latitude: userLocation.coordinate.latitude, longitude: userLocation.coordinate.longitude)
        let destinationCoordinates = CLLocationCoordinate2D(latitude: closestLocation.1.coordinate.latitude, longitude: closestLocation.1.coordinate.longitude)
        
        // create a request for Apple Servers to calculate the ETA to walk to the closest shuttle stop
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: sourceCoordinates, addressDictionary: nil))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destinationCoordinates, addressDictionary: nil))
        request.requestsAlternateRoutes = true
        request.transportType = .walking
        
        // make the request and calculate the ETA
        let directions = MKDirections(request: request)
        directions.calculateETA(completionHandler: { response, error in
            // if the request was successful and there is an arrival time
            if ((response?.expectedTravelTime) != nil) {
                self.travelTime = (response?.expectedTravelTime)! / 60.00
                print("ETA: \(String(describing: self.travelTime))")
            } else {
                print("Error!")
            }
        })
    }
    
    // Then if the walking time is greater than the amount of time before the next shuttle leaves,
    // then suggest the next time they would be able to make.
    // check the current time and then, according to user location, grab the next time at their location (or near their location)
    func getNextShuttleTime() {
        
    }
}

