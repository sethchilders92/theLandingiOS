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
    //constraints
    @IBOutlet weak var mapConstraint: NSLayoutConstraint!
    @IBOutlet weak var timeConstraint: NSLayoutConstraint!
    @IBOutlet weak var locationConstraint: NSLayoutConstraint!
    @IBOutlet weak var moreInfoBtnConstraint: NSLayoutConstraint!
    @IBOutlet weak var tableViewConstraint: NSLayoutConstraint!
    
    
    // views
    @IBOutlet weak var moreInfoBtn: UIButton!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet var outerView: UIView!
    
    // the map
    //@IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var mapView: MKMapView!
    // the display time for next suggested shuttle time
    @IBOutlet weak var displayTime: UILabel!
    
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
    // the shuttle stop coordinates
    var shuttleCoordinates: [Double]!
    // the shuttle schedule
    var schedule: [(String, Int)]!
//    var schedule: [(Timestamp, String)]!
    lazy var db = Firestore.firestore() // the database
    var width: CGFloat = 0.0 //width of the screen -- will be set in btnClick functions
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        width = self.view.frame.size.width
        
        tableViewConstraint.constant = width
        
        // setup the firebase instance
        let settings = db.settings
        
        settings.areTimestampsInSnapshotsEnabled = true
        db.settings = settings

        // get the next shuttle time
        displayTime.font = displayTime.font.withSize(35)
        displayTime.text = "Calculating... 🤓"
        // pass in a closure
//        getFirebaseData(doc:"mc_landing") { returnedTimes in
//            self.convertStringsToTimes(tempSchedule: returnedTimes)
//        }
        
        getFirebaseData(doc: "all_times", { returnedTimes in
            
        })
    }
    
    @IBAction func moreInfoBtnClick(_ sender: UIButton) {
        tableViewConstraint.constant = 0;
        UIView.animate(withDuration: 0.5) {
            self.view.layoutIfNeeded()
            self.moreInfoBtn.isHidden = true
            self.outerView?.backgroundColor = UIColor.white.withAlphaComponent(0.4)
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if tableViewConstraint.constant == 0 {
            let touch: UITouch? = touches.first
            
            if touch?.view != tableView {
                tableViewConstraint.constant = width
                UIView.animate(withDuration: 0.5) {
                    self.view.layoutIfNeeded()
                    self.moreInfoBtn.isHidden = false
                    self.outerView?.backgroundColor = UIColor.white.withAlphaComponent(1)
                }
            }
        }
    }
  
    // This is messy. Get the schedule and locations from Firebase
    // Then modify the retreived data to be in the format you need
    // Assign the member variable 'schedule' to the modified retreived data
    // Change the displayTime text in the UI
    func getFirebaseData(doc:String, _ completion: @escaping ([String]) -> ()) {
        DispatchQueue.global().async {
            self.db.collection("locations").document(doc).getDocument { (document, error) in
                var myTimes: [String] = []
                if let error = error {
                    print("Error getting documents: \(error)")
                } else {
                    print("----------------------------------------------------------------------")
                    print("Document: \(document)")
                    print("----------------------------------------------------------------------")
//                    if let document = document, document.exists {
//                        let locationTimes = document.data()
//                        for times in locationTimes! {
//                            for time in times.value as! [String] {
//                                myTimes.append(time)
//                            }
//                        }
//                    }
                    completion(myTimes)
                }
            }
        }
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
        let region = MKCoordinateRegion(center: center, span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005))
        mapView.mapType = .satellite
        mapView.setRegion(region, animated: true)
        mapView.showsUserLocation = true
        
        // after getting the user's location, find the closest shuttle stop to them
        checkRegion()
        getLocations()
    }
    
    func checkRegion() {
        // Your coordinates go here (lat, lon)
        let geofenceRegionCenter = CLLocationCoordinate2D(
            latitude: userLocation.coordinate.latitude,
            longitude: userLocation.coordinate.longitude
        )
        
        /* Create a region centered on desired location,
         choose a radius for the region (in meters)
         choose a unique identifier for that region */
        let geofenceRegion = CLCircularRegion(
            center: geofenceRegionCenter,
            radius: 500,
            identifier: "UniqueIdentifier"
        )
        
        print("GEOFENCE")
        geofenceRegion.notifyOnEntry = true
        geofenceRegion.notifyOnExit = true
        
        self.locationManager.startMonitoring(for: geofenceRegion)
    }
    
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        if region is CLCircularRegion {
            print("Welcome to Playa Grande! If the waves are good, you can try surfing!")
        }
        print("WORKKKKK")
        //Good place to schedule a local notification
    }
    
    // Bro Barney - If getting the user's location is NOT unsuccessful
    private func locationManger(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Error \(error)")
    }

    // loop throught the locations and find the closest one to the user
    func getLocations() {
        DispatchQueue.global().async {
            // get the 'coordinates' document from firebase with all the locations and their coordinates
            self.db.collection("locations").document("coordinates").getDocument { (document, error) in
                if let error = error {
                    print("Error getting documents: \(error)")
                } else {
                    if let document = document, document.exists {
                        // a variable to store the formatted locations in
                        var locations = [(name: String, location: CLLocation)]()
                        // get the data from the document
                        let locationsData = document.data()
                        // for each item in the document, format it and append it to the 'locations' variable
                        for location in locationsData! {
                            let coord = location.value as! GeoPoint
                            let lat = coord.latitude
                            let lon = coord.longitude
                            locations.append((name: location.key,
                                              location: CLLocation.init(latitude: lat, longitude: lon)))
                        }
                        // make a random location that is far, far away
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
                        DispatchQueue.main.async {
                            // set the member variables
                            self.locations = locations
                            self.closestLocation = tempClosest
//                            print("Closest Location: \(String(describing: self.closestLocation))")
                            // after finding the closest location, calculate walking time
                            self.convertStringsToTimes()
                        }
                    }
                }
            }
        }
    }
    

    /* These next to methods are dependent on each other. Code them carefully. */
    
    // Based on the users location, calculate the walking time to the closest shuttle stop.
//    func getWalkingTime() {
//        // set the source and destination coordinates
//        let sourceCoordinates = CLLocationCoordinate2D(latitude: userLocation.coordinate.latitude,
//                                                       longitude: userLocation.coordinate.longitude)
//        let destinationCoordinates = CLLocationCoordinate2D(latitude: closestLocation.1.coordinate.latitude,
//                                                            longitude: closestLocation.1.coordinate.longitude)
//
//        // create a request for Apple Servers to calculate the ETA to walk to the closest shuttle stop
//        let request = MKDirections.Request()
//        request.source = MKMapItem(placemark: MKPlacemark(coordinate: sourceCoordinates, addressDictionary: nil))
//        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destinationCoordinates, addressDictionary: nil))
//        request.requestsAlternateRoutes = true
//        request.transportType = .walking
//
//        // make the request and calculate the ETA
//        let directions = MKDirections(request: request)
//        directions.calculateETA(completionHandler: { response, error in
//            // if the request was successful and there is an arrival time
//            if ((response?.expectedTravelTime) != nil) {
//                self.travelTime = (response?.expectedTravelTime)!
//                print("ETA: \(String(describing: self.travelTime))")
//                self.convertStringsToTimes()
//            } else {
//                print("Error calculating ETA!")
//            }
//        })
//    }
    
    func convertStringsToTimes() {
        DispatchQueue.global().async {
            var secondsTupleArray = [(String, Int)]()
            for scheduleItem in self.fullSchedule {
                let time = scheduleItem["time"] as! String
                // get the first two and last two characters of the string
                let hour = Int(time.prefix(2))
                let minutes = Int(time.suffix(2))
                let secondsSinceStartOfDay = hour! * 3600 + minutes! * 60

                // determine the postfix
                let postfix = hour! >= 12 ? "pm" : "am"

                // add the leading zero if the minutes are single digits
                let minuteString = minutes! < 10 ? String("0\(minutes!)") : String(minutes!)

                // make the time 12h base instead of 24h base & add the leading zero if necessary
                var hourString = String(hour! > 12 ? hour!-12 : hour!)
                hourString = Int(hourString)! < 10 ? "0\(hourString)" : hourString

                // create the new display time string with the postfix (am/pm)
                let displayString = "\(hourString):\(minuteString) \(postfix)"

                // add the new display string and the calculated seconds to the temp schedule
                secondsTupleArray.append((displayString, secondsSinceStartOfDay))
            }

            DispatchQueue.main.async {
                self.schedule = secondsTupleArray
                self.getNextShuttleTime()
            }
        }
    }
    
    // Then if the walking time is greater than the amount of time before the next shuttle leaves,
    // then suggest the next time they would be able to make.
    // check the current time and then, according to user location, grab the next time at their location (or near their location)
    func getNextShuttleTime() {
        DispatchQueue.global().async {
            let date = Date()
            let calendar = Calendar.current
            let dateComponents = calendar.dateComponents([.hour, .minute], from: date)
            // calculate the number of seconds since the start of the day
            let currentTimeSeconds = dateComponents.hour! * 3600 + dateComponents.minute! * 60
            
            // the default next time says the shuttle isn't running
            var nextTimes: [(String, Int)] = []
            var foundNextTime = 0;
            
            // find the next shuttle time
            for scheduleTime in self.schedule {
                if (foundNextTime < 3 && Double(scheduleTime.1) > Double(currentTimeSeconds)) {//} + self.travelTime) {
                    nextTimes.append(scheduleTime)
                    foundNextTime += 1
                }
            }
            DispatchQueue.main.async {
                self.displayTimes(nextTimes: nextTimes)
            }
        }
    }
    
    func displayTimes(nextTimes: [(String, Int)]) {
        // change the display font size depending on what is to be displayed
        self.displayTime1.font = nextTimes.count > 0 ? self.displayTime1.font.withSize(45): self.displayTime1.font.withSize(25)
        self.displayTime2.font = nextTimes.count > 1 ? self.displayTime2.font.withSize(45): self.displayTime2.font.withSize(25)
        self.displayTime3.font = nextTimes.count > 2 ? self.displayTime3.font.withSize(45): self.displayTime3.font.withSize(25)
        
        // display the suggested shuttle time
        let shuttleStopped = "Stopped for the day"
        self.displayTime1.text = nextTimes.count > 0 ? nextTimes[0].0 : shuttleStopped
        self.displayTime2.text = nextTimes.count > 1 ? nextTimes[1].0 : ""
        self.displayTime3.text = nextTimes.count > 2 ? nextTimes[2].0 : ""
    }
}

// get current location
// get closest location
// determine if that location is on campus

// get times
// sort times
// get three relevant times

