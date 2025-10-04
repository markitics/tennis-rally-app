//
//  LocationManager.swift
//  TennisTracker
//
//  Manages device location for recording match locations
//

import Foundation
import CoreLocation
import Combine

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var currentLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined

    private let locationManager = CLLocationManager()

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest

        // Check current authorization status
        authorizationStatus = locationManager.authorizationStatus

        // Request permission if not determined
        if authorizationStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        }

        // Start updating location if authorized
        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            locationManager.startUpdatingLocation()
        }
    }

    // MARK: - CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus

        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            locationManager.startUpdatingLocation()
        } else {
            locationManager.stopUpdatingLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        currentLocation = location

        // Stop updating after we get a location (saves battery)
        // We'll restart when needed for the next match
        locationManager.stopUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ Location manager failed with error: \(error.localizedDescription)")
    }

    // Request a fresh location update (call when starting a new match)
    func requestLocation() {
        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            locationManager.startUpdatingLocation()
        } else if authorizationStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        }
    }
}
