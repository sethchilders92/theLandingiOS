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

class FirstViewController: UIViewController {
    
    // the map
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var displayTime: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // setup the firebase instance
        let db = Firestore.firestore()
        let settings = db.settings
        settings.areTimestampsInSnapshotsEnabled = true
        db.settings = settings

        // get the next shuttle time
        self.displayTime.font = displayTime.font.withSize(25)
        self.displayTime.text = "Calculating... 🤓"
        updateTime()
//        getFirebaseData(db: db)
    }
    
    func getFirebaseData(db: Firestore) {
        var myTimes: Array<String> = []
        
        DispatchQueue.main.async {
            db.collection("locations").getDocuments { (querySnapshot, error) in
                if let error = error {
                    print("Error getting documents: \(error)")
                } else {
                    for document in querySnapshot!.documents {
                        let locationTimes = document.data()
                        for times in locationTimes {
                            for time in times.value as! Array<String> {
                                myTimes.append(time)
                            }
                        }
                    }
                    print("myTimes1: \(myTimes[0])")
                    self.displayTime.text = myTimes[0]
                }
            }
        }
//        print("myTimes2: \(myTimes)")
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
        self.displayTime.font = displayTime.font.withSize(45)
        self.displayTime.text = "\(currentHour-12):\(currentMinutes) \(postfix)"
    }

    // Map setup
    let locationManager = CLLocationManager()
    func checkLocationAuthorizationStatus() {
        if CLLocationManager.authorizationStatus() == .authorizedWhenInUse {
            let center = CLLocationCoordinate2D(latitude: 43.817403, longitude: -111.788488)
            let region = MKCoordinateRegion(center: center, span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
            self.mapView.mapType = .satellite
            self.mapView.setRegion(region, animated: true)
            self.mapView.showsUserLocation = true
        } else {
            locationManager.requestWhenInUseAuthorization()
        }
    }
    
    // Map rendering
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        checkLocationAuthorizationStatus()
    }
    
    
}

