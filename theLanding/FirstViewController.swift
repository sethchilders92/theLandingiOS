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
    // the map
    @IBOutlet weak var mapView: MKMapView!
    // the display time for next suggested shuttle time
    @IBOutlet weak var displayTime: UILabel!
    // the shuttle schedule
    var schedule: [String]!
    
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
    }
    
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
                        print("myTimes1: \(myTimes[0])")
                        self.schedule = myTimes
                        self.displayTime.text = self.schedule[0]
                    }
                }
            }
        }
    }
    
    // Time updating and formatting
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

    // Bro Barney
    func findCurrentLocation() {
        locationManager = CLLocationManager()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestAlwaysAuthorization()
        
        if CLLocationManager.locationServicesEnabled() {
            locationManager.startUpdatingLocation()
        }
    }
    
    // Bro Barney
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let userLocation:CLLocation = locations[0] as CLLocation
        // manager.stopUpdatingLocation()
        
        let center = CLLocationCoordinate2D(latitude: userLocation.coordinate.latitude, longitude: userLocation.coordinate.longitude)
        let region = MKCoordinateRegion(center: center, span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
        mapView.mapType = .satellite
        mapView.setRegion(region, animated: true)
        mapView.showsUserLocation = true

        print("latitude = \(userLocation.coordinate.latitude)")
        print("longitude = \(userLocation.coordinate.longitude)")
    }
    
    // Bro Barney
    private func locationManger(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Error \(error)")
    }
    
    // Map setup
    func checkLocationAuthorizationStatus() {
        if CLLocationManager.authorizationStatus() == .authorizedWhenInUse {
            let center = CLLocationCoordinate2D(latitude: 43.817403, longitude: -111.788488)
            let region = MKCoordinateRegion(center: center, span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
            mapView.mapType = .satellite
            mapView.setRegion(region, animated: true)
            mapView.showsUserLocation = true
        } else {
            locationManager.requestWhenInUseAuthorization()
        }
    }
    
    // Map rendering
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        findCurrentLocation()
    }
    
    
}

