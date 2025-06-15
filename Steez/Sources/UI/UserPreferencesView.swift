import SwiftUI
import CoreLocation

struct UserPreferencesView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var locationService = LocationService()
    @State private var selectedSize: String = "M"
    @State private var selectedCountryCode: String = "US"
    @State private var showingCountryPicker = false
    @State private var useLocation = true
    @State private var showLocationAlert = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                        
                        Text("Set Your Preferences")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Help us find clothing in your size and region")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 20)
                    
                    // Size Selection
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "tshirt.fill")
                                .foregroundColor(.blue)
                            Text("Clothing Size")
                                .font(.headline)
                            Spacer()
                        }
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                            ForEach(LocationService.clothingSizes, id: \.self) { size in
                                SizeButton(
                                    size: size,
                                    isSelected: selectedSize == size,
                                    action: { selectedSize = size }
                                )
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(16)
                    
                    // Country/Location Selection
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "location.fill")
                                .foregroundColor(.blue)
                            Text("Region")
                                .font(.headline)
                            Spacer()
                            
                            if locationService.isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                        }
                        
                        // Location Toggle
                        VStack {
                            Toggle("Use my location", isOn: $useLocation)
                                .onChange(of: useLocation) { newValue in
                                    if newValue {
                                        handleLocationToggle()
                                    } else {
                                        selectedCountryCode = "US"
                                    }
                                }
                            
                            if useLocation {
                                LocationStatusView(
                                    locationService: locationService,
                                    selectedCountryCode: $selectedCountryCode,
                                    showLocationAlert: $showLocationAlert
                                )
                            } else {
                                ManualCountrySelector(
                                    selectedCountryCode: $selectedCountryCode,
                                    showingCountryPicker: $showingCountryPicker
                                )
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(16)
                    
                    Spacer(minLength: 20)
                    
                    // Continue Button
                    Button(action: savePreferences) {
                        HStack {
                            Text("Continue")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            Image(systemName: "arrow.right")
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                    }
                }
                .padding()
            }
            .navigationTitle("Preferences")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                selectedSize = appState.userSize
                selectedCountryCode = appState.userCountry
            }
            .onChange(of: locationService.currentCountryCode) { newCountryCode in
                if useLocation {
                    selectedCountryCode = newCountryCode
                }
            }
            .sheet(isPresented: $showingCountryPicker) {
                CountryPickerSheet(selectedCountryCode: $selectedCountryCode)
            }
            .alert("Location Access", isPresented: $showLocationAlert) {
                Button("Settings") {
                    locationService.openLocationSettings()
                }
                Button("Not Now", role: .cancel) {
                    useLocation = false
                }
            } message: {
                Text("To automatically detect your country, please enable location access in Settings.")
            }
        }
    }
    
    private func handleLocationToggle() {
        switch locationService.authorizationStatus {
        case .notDetermined:
            locationService.requestLocationPermission()
        case .denied, .restricted:
            showLocationAlert = true
        case .authorizedWhenInUse, .authorizedAlways:
            locationService.getCurrentLocation()
        @unknown default:
            break
        }
    }
    
    private func savePreferences() {
        appState.userSize = selectedSize
        appState.userCountry = selectedCountryCode
        appState.locationPermissionGranted = locationService.authorizationStatus == .authorizedWhenInUse || locationService.authorizationStatus == .authorizedAlways
        appState.saveUserPreferences()
    }
}

// MARK: - Supporting Views

struct SizeButton: View {
    let size: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(size)
                .font(.headline)
                .foregroundColor(isSelected ? .white : .primary)
                .frame(height: 44)
                .frame(maxWidth: .infinity)
                .background(isSelected ? Color.blue : Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color.blue : Color(.systemGray3), lineWidth: 1)
                )
                .cornerRadius(8)
        }
    }
}

struct LocationStatusView: View {
    @ObservedObject var locationService: LocationService
    @Binding var selectedCountryCode: String
    @Binding var showLocationAlert: Bool
    
    var body: some View {
        VStack {
            switch locationService.authorizationStatus {
            case .notDetermined:
                Text("Tap to allow location access")
                    .foregroundColor(.secondary)
            case .denied, .restricted:
                VStack(spacing: 8) {
                    Text("Location access denied")
                        .foregroundColor(.orange)
                    Button("Open Settings") {
                        showLocationAlert = true
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            case .authorizedWhenInUse, .authorizedAlways:
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Detected: \(locationService.currentCountryName)")
                        .foregroundColor(.secondary)
                    Spacer()
                }
            @unknown default:
                Text("Unknown location status")
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct ManualCountrySelector: View {
    @Binding var selectedCountryCode: String
    @Binding var showingCountryPicker: Bool
    
    var body: some View {
        Button(action: { showingCountryPicker = true }) {
            HStack {
                Text("Country: \(LocationService.getCountryName(for: selectedCountryCode))")
                    .foregroundColor(.primary)
                Spacer()
                Image(systemName: "chevron.down")
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(.systemGray3), lineWidth: 1)
            )
        }
    }
}

struct CountryPickerSheet: View {
    @Binding var selectedCountryCode: String
    @Environment(\.presentationMode) var presentationMode
    @State private var searchText = ""
    
    private var filteredCountries: [(String, String)] {
        if searchText.isEmpty {
            return LocationService.supportedCountries
        } else {
            return LocationService.supportedCountries.filter { country in
                country.1.localizedCaseInsensitiveContains(searchText) ||
                country.0.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            List {
                SearchBar(text: $searchText, placeholder: "Search countries...")
                    .listRowInsets(EdgeInsets())
                
                ForEach(filteredCountries, id: \.0) { country in
                    Button(action: {
                        selectedCountryCode = country.0
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        HStack {
                            Text(country.1)
                                .foregroundColor(.primary)
                            Spacer()
                            if selectedCountryCode == country.0 {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Country")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}

struct SearchBar: View {
    @Binding var text: String
    let placeholder: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField(placeholder, text: $text)
                .textFieldStyle(PlainTextFieldStyle())
            
            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(8)
        .background(Color(.systemGray6))
        .cornerRadius(8)
        .padding(.horizontal)
    }
}

struct UserPreferencesView_Previews: PreviewProvider {
    static var previews: some View {
        UserPreferencesView()
            .environmentObject(AppState())
    }
} 