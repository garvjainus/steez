import Foundation
import CoreLocation
import UIKit

class LocationService: NSObject, ObservableObject {
    private let locationManager = CLLocationManager()
    
    @Published var authorizationStatus: CLAuthorizationStatus
    @Published var currentCountryCode: String = "US"
    @Published var currentCountryName: String = "United States"
    @Published var isLoading: Bool = false
    
    override init() {
        self.authorizationStatus = locationManager.authorizationStatus
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyReduced // For country detection, reduced accuracy is fine
    }
    
    func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    func getCurrentLocation() {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            print("Location access not authorized")
            return
        }
        
        isLoading = true
        locationManager.requestLocation()
    }
    
    func openLocationSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            if UIApplication.shared.canOpenURL(settingsUrl) {
                UIApplication.shared.open(settingsUrl)
            }
        }
    }
    
    private func updateCountryFromLocation(_ location: CLLocation) {
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    print("Reverse geocoding error: \(error.localizedDescription)")
                    return
                }
                
                if let placemark = placemarks?.first,
                   let countryCode = placemark.isoCountryCode,
                   let countryName = placemark.country {
                    self?.currentCountryCode = countryCode
                    self?.currentCountryName = countryName
                    print("Detected country: \(countryName) (\(countryCode))")
                }
            }
        }
    }
}

extension LocationService: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        updateCountryFromLocation(location)
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.isLoading = false
        }
        print("Location manager error: \(error.localizedDescription)")
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async {
            self.authorizationStatus = manager.authorizationStatus
            
            // Automatically try to get location if permission is granted
            if self.authorizationStatus == .authorizedWhenInUse || self.authorizationStatus == .authorizedAlways {
                self.getCurrentLocation()
            }
        }
    }
}

// MARK: - Country/Size Constants
extension LocationService {
    static let clothingSizes = ["XS", "S", "M", "L", "XL", "XXL"]
    
    static let supportedCountries = [
        ("US", "United States"),
        ("GB", "United Kingdom"),
        ("CA", "Canada"),
        ("AU", "Australia"),
        ("DE", "Germany"),
        ("FR", "France"),
        ("IT", "Italy"),
        ("ES", "Spain"),
        ("JP", "Japan"),
        ("KR", "South Korea"),
        ("IN", "India"),
        ("BR", "Brazil"),
        ("MX", "Mexico"),
        ("NL", "Netherlands"),
        ("BE", "Belgium"),
        ("AT", "Austria"),
        ("CH", "Switzerland"),
        ("SE", "Sweden"),
        ("NO", "Norway"),
        ("DK", "Denmark"),
        ("FI", "Finland"),
        ("PL", "Poland"),
        ("CZ", "Czech Republic"),
        ("HU", "Hungary"),
        ("RO", "Romania"),
        ("BG", "Bulgaria"),
        ("HR", "Croatia"),
        ("GR", "Greece"),
        ("PT", "Portugal"),
        ("IE", "Ireland"),
        ("LU", "Luxembourg"),
        ("MT", "Malta"),
        ("CY", "Cyprus"),
        ("LV", "Latvia"),
        ("LT", "Lithuania"),
        ("EE", "Estonia"),
        ("SK", "Slovakia"),
        ("SI", "Slovenia")
    ]
    
    static func getCountryName(for code: String) -> String {
        return supportedCountries.first { $0.0 == code }?.1 ?? code
    }
} 