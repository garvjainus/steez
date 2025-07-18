import SwiftUI
import CoreLocation

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct UserPreferencesView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var locationService = LocationService()
    @State private var selectedSize: String = "M"
    @State private var selectedCountryCode: String = "US"
    @State private var showingCountryPicker = false
    @State private var useLocation = true
    @State private var showLocationAlert = false
    
    // Animation states
    @State private var headerAnimated = false
    @State private var sizeAnimated = false
    @State private var locationAnimated = false
    @State private var buttonAnimated = false
    
    var body: some View {
        ZStack {
            SteezColors.background
                .ignoresSafeArea()
            
            VStack(spacing: 32) {
                // Header
                VStack(spacing: 16) {
                    Text("Tell us about yourself")
                        .font(SteezFonts.medium(32))
                        .foregroundColor(SteezColors.textPrimary)
                    
                    Text("We'll personalize your experience to find the perfect fits")
                        .font(SteezFonts.regular(16))
                        .foregroundColor(SteezColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                .padding(.top, 48)
                .opacity(headerAnimated ? 1 : 0)
                .offset(y: headerAnimated ? 0 : -20)
                
                // Content Cards
                VStack(spacing: 24) {
                    // Size Selection
                    PreferenceCard(
                        icon: "tshirt.fill",
                        title: "Your Size",
                        subtitle: "What size do you usually wear?",
                        isAnimated: sizeAnimated
                    ) {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                            ForEach(LocationService.clothingSizes, id: \.self) { size in
                                SizeButton(
                                    size: size,
                                    isSelected: selectedSize == size,
                                    action: {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                            selectedSize = size
                                        }
                                        
                                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                        impactFeedback.impactOccurred()
                                    }
                                )
                            }
                        }
                    }
                    
                    // Location Selection
                    PreferenceCard(
                        icon: "location.fill",
                        title: "Your Region",
                        subtitle: "Where should we search for items?",
                        isAnimated: locationAnimated
                    ) {
                        VStack(spacing: 16) {
                            Toggle(isOn: $useLocation) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Use my current location")
                                        .font(SteezFonts.medium(16))
                                        .foregroundColor(SteezColors.textPrimary)
                                    
                                    Text("Automatically detect your country")
                                        .font(SteezFonts.regular(14))
                                        .foregroundColor(SteezColors.textSecondary)
                                }
                            }
                            .toggleStyle(SwitchToggleStyle(tint: SteezColors.primary))
                            .onChange(of: useLocation) { newValue in
                                handleLocationToggle()
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
                }
                .padding(.horizontal, 24)
                
                Spacer()
                
                // Action Button
                Button("Complete Setup", action: savePreferences)
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                    .opacity(buttonAnimated ? 1 : 0)
                    .offset(y: buttonAnimated ? 0 : 30)
            }
        }
        .onAppear(perform: animateViews)
        .sheet(isPresented: $showingCountryPicker) {
            CountryPicker(selectedCountryCode: $selectedCountryCode)
        }
        .alert(isPresented: $showLocationAlert) {
            Alert(
                title: Text("Location Permission"),
                message: Text("Please enable location services in Settings to automatically detect your country."),
                primaryButton: .default(Text("Settings"), action: {
                    locationService.openLocationSettings()
                }),
                secondaryButton: .cancel()
            )
        }
    }
    
    private func animateViews() {
        withAnimation(.easeOut(duration: 0.8)) {
            headerAnimated = true
        }
        withAnimation(.easeOut(duration: 0.8).delay(0.2)) {
            sizeAnimated = true
        }
        withAnimation(.easeOut(duration: 0.8).delay(0.4)) {
            locationAnimated = true
        }
        withAnimation(.easeOut(duration: 0.8).delay(0.6)) {
            buttonAnimated = true
        }
    }
    
    private func handleLocationToggle() {
        if useLocation {
            locationService.requestLocationPermission()
            
            if locationService.authorizationStatus == .denied || locationService.authorizationStatus == .restricted {
                showLocationAlert = true
            } else {
                locationService.getCurrentLocation()
            }
        } else {
            selectedCountryCode = "US"
        }
    }
    
    private func savePreferences() {
        appState.userSize = selectedSize
        appState.userCountry = selectedCountryCode
        appState.locationPermissionGranted = useLocation && (locationService.authorizationStatus == .authorizedWhenInUse || locationService.authorizationStatus == .authorizedAlways)
        appState.saveUserPreferences()
    }
}

// MARK: - Preference Card
struct PreferenceCard<Content: View>: View {
    let icon: String
    let title: String
    let subtitle: String
    let isAnimated: Bool
    let content: Content
    
    init(icon: String, title: String, subtitle: String, isAnimated: Bool, @ViewBuilder content: () -> Content) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.isAnimated = isAnimated
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color(red: 0.54, green: 0.17, blue: 0.22).opacity(0.1))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(Color(red: 0.54, green: 0.17, blue: 0.22))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.custom("IBMPlexSans-Medium", size: 18))
                        .foregroundColor(.black)
                    
                    Text(subtitle)
                        .font(.custom("IBMPlexSans-Regular", size: 14))
                        .foregroundColor(.gray)
                }
                
                Spacer()
            }
            
            // Content
            content
        }
        .padding(24)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 2)
        .scaleEffect(isAnimated ? 1.0 : 0.9)
        .opacity(isAnimated ? 1.0 : 0.0)
        .offset(y: isAnimated ? 0 : 20)
        .animation(.spring(response: 0.8, dampingFraction: 0.8), value: isAnimated)
    }
}

struct SizeButton: View {
    let size: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(size)
                .font(.custom("IBMPlexSans-Medium", size: 16))
                .foregroundColor(isSelected ? .white : .black)
                .frame(height: 48)
                .frame(maxWidth: .infinity)
                .background(
                    Group {
                        if isSelected {
                            LinearGradient(
                                colors: [
                                    Color(red: 0.54, green: 0.17, blue: 0.22),
                                    Color(red: 0.64, green: 0.27, blue: 0.32)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        } else {
                            Color.clear
                        }
                    }
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            isSelected ? Color.clear : Color.gray.opacity(0.3),
                            lineWidth: 1
                        )
                )
                .cornerRadius(12)
                .scaleEffect(isSelected ? 1.05 : 1.0)
                .shadow(color: isSelected ? Color(red: 0.54, green: 0.17, blue: 0.22).opacity(0.3) : Color.clear, radius: 5, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct CustomToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(configuration.isOn ? Color(red: 0.54, green: 0.17, blue: 0.22) : Color.gray.opacity(0.3))
                .frame(width: 50, height: 30)
                .overlay(
                    Circle()
                        .fill(Color.white)
                        .frame(width: 26, height: 26)
                        .offset(x: configuration.isOn ? 10 : -10)
                        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: configuration.isOn)
                )
                .onTapGesture {
                    configuration.isOn.toggle()
                }
        }
    }
}

// Keep existing supporting views with minor style updates
struct LocationStatusView: View {
    @ObservedObject var locationService: LocationService
    @Binding var selectedCountryCode: String
    @Binding var showLocationAlert: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if locationService.isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Detecting your location...")
                        .font(.custom("IBMPlexSans-Regular", size: 14))
                        .foregroundColor(.gray)
                }
            } else if !locationService.currentCountryCode.isEmpty {
                HStack {
                    Image(systemName: "location.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 12))
                    Text("Detected: \(LocationService.getCountryName(for: locationService.currentCountryCode))")
                         .font(.custom("IBMPlexSans-Regular", size: 14))
                         .foregroundColor(.green)
                }
            } else {
                HStack {
                    Image(systemName: "location.slash")
                        .foregroundColor(.red)
                        .font(.system(size: 12))
                    Text("Location not available")
                        .font(.custom("IBMPlexSans-Regular", size: 14))
                        .foregroundColor(.red)
                }
            }
        }
        .padding(16)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
}

struct ManualCountrySelector: View {
    @Binding var selectedCountryCode: String
    @Binding var showingCountryPicker: Bool
    
    var body: some View {
        Button(action: { showingCountryPicker = true }) {
            HStack {
                Text(LocationService.getCountryName(for: selectedCountryCode))
                     .font(.custom("IBMPlexSans-Regular", size: 16))
                     .foregroundColor(.black)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
                    .font(.system(size: 14))
            }
            .padding(16)
            .background(Color.gray.opacity(0.05))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Country Picker
struct CountryPicker: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedCountryCode: String
    @State private var searchText = ""
    
    var filteredCountries: [LocationService.Country] {
        if searchText.isEmpty {
            return LocationService.supportedCountries
        } else {
            return LocationService.supportedCountries.filter {
                $0.name.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                SearchBar(searchText: $searchText)
                    .padding(.horizontal)
                
                List(filteredCountries, id: \.code) { country in
                    Button(action: {
                        selectedCountryCode = country.code
                        dismiss()
                    }) {
                        HStack {
                            Text(country.name)
                                .font(SteezFonts.regular(16))
                                .foregroundColor(SteezColors.textPrimary)
                            
                            Spacer()
                            
                            if selectedCountryCode == country.code {
                                Image(systemName: "checkmark")
                                    .foregroundColor(SteezColors.primary)
                            }
                        }
                    }
                }
                .listStyle(PlainListStyle())
            }
            .navigationTitle("Select Country")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Search Bar
struct SearchBar: View {
    @Binding var searchText: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(SteezColors.textSecondary)
            
            TextField("Search", text: $searchText)
                .font(SteezFonts.regular(16))
                .foregroundColor(SteezColors.textPrimary)
            
            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(SteezColors.textSecondary)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(SteezColors.textSecondary.opacity(0.1))
        )
    }
}

#Preview {
    UserPreferencesView()
        .environmentObject(AppState())
} 