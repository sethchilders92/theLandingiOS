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
    
    //components
    @IBOutlet weak var displayLocation1: UITextField!
    @IBOutlet weak var displayLocation2: UITextField!
    @IBOutlet weak var displayLocation3: UITextField!
    @IBOutlet weak var mapView: MKMapView!     // the map
    @IBOutlet weak var displayTime1: UITextField! // the display time for next suggested shuttle time
    @IBOutlet weak var displayTime2: UITextField! // the display time for next suggested shuttle time
    @IBOutlet weak var displayTime3: UITextField! // the display time for next suggested shuttle time
    @IBOutlet weak var moreInfoBtn: UIButton!  // the button for the user to get more times
    @IBOutlet var safeAreaView: UIView!        // the safe area component
    @IBOutlet weak var tableView: UITableView! // the component that holds all of the times
    
    //component constraints to allow for "page transitions"
    @IBOutlet weak var locationConstraint: NSLayoutConstraint!
    @IBOutlet weak var displayTime1Constraint: NSLayoutConstraint!
    @IBOutlet weak var displayTime2Constraint: NSLayoutConstraint!
    @IBOutlet weak var displayTime3Constraint: NSLayoutConstraint!
    @IBOutlet weak var mapConstraint: NSLayoutConstraint!
    @IBOutlet var moreInfoBtnConstraint: UIView!
    @IBOutlet weak var tableViewConstraint: NSLayoutConstraint!
    
    var locationManager:CLLocationManager! // location manager
    var userLocation:CLLocation! // user location
    var locations: [(name: String, location: CLLocation)]! // an array of all the locations
    var closestLocation: (name: String, location: CLLocation, distance: Double)! // closest stop to user's current location
    var metersToShuttleStop: [CLLocationDistance]! // distance to next stop
    var travelTime: Double! // walking time in minutes to closest shuttle stop
    var shuttleCoordinates: [Double]! // the shuttle stop coordinates
    var fullSchedule: [Dictionary<String, Any>]! // the full schedule from firebase
    var schedule: [(String, Int, Dictionary<String, Any>)]! // the shuttle schedule
    lazy var db = Firestore.firestore() // the database
    var width: CGFloat = 0.0 //width of the screen -- will be set in btnClick functions
    
    /********************************************
    * viewDidLoad
    *
    * This serves as a constructor and initializes
    * the app at start.
    ********************************************/
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //set the components and hides certain features
        width = self.view.frame.size.width
        tableViewConstraint.constant = width
        
        // setup the firebase instance
        let settings = db.settings
        
        settings.areTimestampsInSnapshotsEnabled = true
        db.settings = settings
        
//        self.displayLocation1.borderStyle = UITextBorderStyleRoundedRect
        
        // get the weekday's symbolic letter to help filter times down as seen below
        let weekday = getWeekday()

        // get the shuttle times
        getFirebaseData() { returnedTimes in
            // sort the schedule by time from earliest to latest times in the day
            self.fullSchedule = returnedTimes.sorted { $1["time"] as! String > $0["time"] as! String }
            // filter out the times that are for days other than the current day
            self.fullSchedule = self.fullSchedule.filter {
                (scheduleItem: Dictionary<String, Any>) in
                let day = scheduleItem["days"] as! String
                return day.contains(weekday)
            }
            self.findCurrentLocation()
        }
    }
  
    func getWeekday() -> String {
        // This currently isn't getting the correct timezone so it says it's a new day when it isn't yet
        let date = Date()
        let dateFormatter = DateFormatter()
        
        // get the day number
        dateFormatter.dateFormat = "e"
        let currentDateString: String = dateFormatter.string(from: date)
        
        // write switch statement to assign/return day string (eg. r, t, s, m)
        var today = ""
        switch currentDateString {
            case "1": today = "m"
            case "2": today = "t"
            case "3": today = "w"
            case "4": today = "r"
            case "5": today = "f"
            case "6": today = "s"
            default: today = "incorrect"
        }
        
        // return the single letter determining which day it is
        return today
    }
    
    /********************************************
     * getFirebaseData
     *
     * This makes an asynchronous call to Firebase
     * and gets all of the scheduled times as
     * needed.
     ********************************************/
    func getFirebaseData(_ completion: @escaping ([Dictionary<String, Any>]) -> ()) {
        DispatchQueue.global().async {
            self.db.collection("locations").document("all_times").getDocument { (document, error) in
                var myTimes: [Dictionary<String, Any>] = []
                if let error = error {
                    print("Error getting documents: \(error)")
                } else {
                    if let document = document, document.exists {
                        if let locationTimes = document.data() {
                            if let times = locationTimes["all_times"] {
                                let arrayTimes:[Dictionary<String,Any>] = times as! [Dictionary<String, Any>]
                                for time in arrayTimes {
                                    myTimes.append(time)
//                                    print(time)
                                }
                            }
                        }
                    }
                    completion(myTimes)
                }
            }
        }
    }
    
    /********************************************
     * moreInfoBtnClick
     *
     * This function is called when the button
     * is clicked and it animates the tableView
     * moving over.
     ********************************************/
    @IBAction func moreInfoBtnClick(_ sender: UIButton) {
        tableViewConstraint.constant = 0
        UIView.animate(withDuration: 0.5) {
            self.view.layoutIfNeeded()
            self.moreInfoBtn.alpha = 0
            self.safeAreaView?.backgroundColor = UIColor.white.withAlphaComponent(0.4)
        }
    }
    
    /********************************************
     * touchesBegan
     *
     * This function overrides the native function
     * and defines what happens to the table view
     * when an user clicks on the view outside of
     * tableView.
     ********************************************/
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if tableViewConstraint.constant == 0 {
            let touch: UITouch? = touches.first
            
            if touch?.view != tableView {
                tableViewConstraint.constant = width
                UIView.animate(withDuration: 0.5) {
                    self.view.layoutIfNeeded()
                    self.moreInfoBtn.alpha = 1
                    self.safeAreaView?.backgroundColor = UIColor.white.withAlphaComponent(1)
                }
            }
        }
    }
    
    /********************************************
     * swipeAway
     *
     * This function handles the user "swiping"
     * away the table view.
     ********************************************/
    @IBAction func swipeAway(_ sender: UISwipeGestureRecognizer) {
        if tableViewConstraint.constant == 0 &&
            sender.state == .ended {
            tableViewConstraint.constant = width
            UIView.animate(withDuration: 0.5) {
                self.view.layoutIfNeeded()
                self.moreInfoBtn.alpha = 1
                self.safeAreaView?.backgroundColor = UIColor.white.withAlphaComponent(1)
            }
        }
    }
    
    /********************************************
     * findCurrentLocation
     *
     * This gets the current location of the user
     * Much thanks to Br. Barney for his help with
     * this code.
     ********************************************/
    func findCurrentLocation() {
        locationManager = CLLocationManager()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestAlwaysAuthorization()

        if CLLocationManager.locationServicesEnabled() {
            locationManager.startUpdatingLocation()
        }
    }
    
    /********************************************
     * locationManager
     *
     * This function determines if the user's
     * location is successful.
     ********************************************/
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
        getLocations()
    }
    
    /********************************************
     * locationManager
     *
     * This handles the situation when getting the
     * user's location was not successful.
     ********************************************/
    private func locationManger(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Error \(error)")
    }

    /********************************************
     * getLocations
     *
     * This determines the times/location.
     ********************************************/
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

                        DispatchQueue.main.async {
                            self.locations = locations // set the member variables
                            self.convertStringsToTimes() // after finding the closest location, calculate walking time
                        }
                    }
                }
            }
        }
    }
    
    func convertStringsToTimes() {
        DispatchQueue.global().async {
            var secondsTupleArray = [(String, Int, Dictionary<String, Any>)]()
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
                secondsTupleArray.append((displayString, secondsSinceStartOfDay, scheduleItem))
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
            var nextTimes: [(String, Int, Dictionary<String, Any>)] = []
            var foundNextTime = 0;
            
            // find the next 3 shuttle times
            for scheduleTime in self.schedule {
                if (foundNextTime < 3 && Double(scheduleTime.1) > Double(currentTimeSeconds)) {//} + self.travelTime) {
                    nextTimes.append(scheduleTime)
                    foundNextTime += 1
                }
            }
            DispatchQueue.main.async {
                self.displayTimes(nextTimes: nextTimes)
                print(nextTimes)
            }
        }
    }
    
    func displayTimes(nextTimes: [(String, Int, Dictionary<String, Any>)]) {
        // change the display font size depending on what is to be displayed
        self.displayTime1.font = nextTimes.count > 0 ? self.displayTime1.font!.withSize(23): self.displayTime1.font!.withSize(25)
        self.displayTime2.font = nextTimes.count > 1 ? self.displayTime2.font!.withSize(23): self.displayTime2.font!.withSize(25)
        self.displayTime3.font = nextTimes.count > 2 ? self.displayTime3.font!.withSize(23): self.displayTime3.font!.withSize(25)

        // display the suggested shuttle time
        let shuttleStopped = "Stopped for the day"
        self.displayLocation1.text = nextTimes.count > 0 ? "\(nextTimes[0].2["start"] as! String) ⇨ \(nextTimes[0].2["end"] as! String)" : shuttleStopped
        self.displayLocation2.text = nextTimes.count > 1 ? "\(nextTimes[1].2["start"] as! String) ⇨ \(nextTimes[1].2["end"] as! String)" : ""
        self.displayLocation3.text = nextTimes.count > 2 ? "\(nextTimes[2].2["start"] as! String) ⇨ \(nextTimes[2].2["end"] as! String)" : ""

        self.displayTime1.text = nextTimes.count > 0 ? nextTimes[0].0 : ""
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
