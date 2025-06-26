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
    
    struct Country {
        let code: String
        let name: String
    }
    
    static let supportedCountries = [
        Country(code: "US", name: "United States"),
        Country(code: "GB", name: "United Kingdom"),
        Country(code: "CA", name: "Canada"),
        Country(code: "AU", name: "Australia"),
        Country(code: "DE", name: "Germany"),
        Country(code: "FR", name: "France"),
        Country(code: "IT", name: "Italy"),
        Country(code: "ES", name: "Spain"),
        Country(code: "JP", name: "Japan"),
        Country(code: "KR", name: "South Korea"),
        Country(code: "IN", name: "India"),
        Country(code: "BR", name: "Brazil"),
        Country(code: "MX", name: "Mexico"),
        Country(code: "NL", name: "Netherlands"),
        Country(code: "BE", name: "Belgium"),
        Country(code: "AT", name: "Austria"),
        Country(code: "CH", name: "Switzerland"),
        Country(code: "SE", name: "Sweden"),
        Country(code: "NO", name: "Norway"),
        Country(code: "DK", name: "Denmark"),
        Country(code: "FI", name: "Finland"),
        Country(code: "PL", name: "Poland"),
        Country(code: "CZ", name: "Czech Republic"),
        Country(code: "HU", name: "Hungary"),
        Country(code: "RO", name: "Romania"),
        Country(code: "BG", name: "Bulgaria"),
        Country(code: "HR", name: "Croatia"),
        Country(code: "GR", name: "Greece"),
        Country(code: "PT", name: "Portugal"),
        Country(code: "IE", name: "Ireland"),
        Country(code: "LU", name: "Luxembourg"),
        Country(code: "MT", name: "Malta"),
        Country(code: "CY", name: "Cyprus"),
        Country(code: "LV", name: "Latvia"),
        Country(code: "LT", name: "Lithuania"),
        Country(code: "EE", name: "Estonia"),
        Country(code: "SK", name: "Slovakia"),
        Country(code: "SI", name: "Slovenia")
    ]
    
    static func countryName(for code: String) -> String {
        return supportedCountries.first { $0.code == code }?.name ?? code
    }
    
    static func getCountryName(for code: String) -> String {
        return countryName(for: code)
    }
} 