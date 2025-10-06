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

    // Desired accuracy threshold (in meters) - only accept locations accurate to within 50m
    private let accuracyThreshold: CLLocationAccuracy = 50.0

    // Timeout for waiting for accurate location (in seconds)
    private let accuracyTimeout: TimeInterval = 10.0
    private var locationStartTime: Date?

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest

        // Additional accuracy settings for outdoor sports tracking
        locationManager.distanceFilter = kCLDistanceFilterNone  // Report all movements
        locationManager.activityType = .fitness  // Optimize for fitness tracking

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

        // Check if this is the first location update since requesting
        if locationStartTime == nil {
            locationStartTime = Date()
        }

        let timeSinceStart = Date().timeIntervalSince(locationStartTime ?? Date())
        let isAccurate = location.horizontalAccuracy >= 0 && location.horizontalAccuracy <= accuracyThreshold
        let timedOut = timeSinceStart >= accuracyTimeout

        print("📍 Location update: accuracy=\(location.horizontalAccuracy)m, age=\(abs(location.timestamp.timeIntervalSinceNow))s, waitTime=\(String(format: "%.1f", timeSinceStart))s")

        // Accept location if:
        // 1. It meets our accuracy threshold, OR
        // 2. We've timed out waiting (use best available)
        if isAccurate || timedOut {
            currentLocation = location
            locationManager.stopUpdatingLocation()
            locationStartTime = nil

            if isAccurate {
                print("✅ Accepted accurate location: \(location.horizontalAccuracy)m accuracy")
            } else {
                print("⏱️ Timeout - accepting best available location: \(location.horizontalAccuracy)m accuracy")
            }
        } else {
            // Keep waiting for more accurate location
            print("⏳ Waiting for more accurate location (current: \(location.horizontalAccuracy)m, want: ≤\(accuracyThreshold)m)")
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ Location manager failed with error: \(error.localizedDescription)")
    }

    // Request a fresh location update (call when starting a new match)
    func requestLocation() {
        // Reset the timer for accuracy check
        locationStartTime = nil
        currentLocation = nil  // Clear stale location

        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            print("📍 Requesting fresh location for new match...")
            locationManager.startUpdatingLocation()
        } else if authorizationStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        }
    }
}
