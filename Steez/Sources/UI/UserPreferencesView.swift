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
    @State private var currentStep = 0
    @State private var progressValue: CGFloat = 0.5
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background with subtle gradient
                LinearGradient(
                    colors: [
                        Color(hex: "FCFCFC"),
                        Color.white
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                // Floating background elements
                ForEach(0..<4, id: \.self) { i in
                    Circle()
                        .fill(Color(red: 0.54, green: 0.17, blue: 0.22).opacity(0.05))
                        .frame(width: CGFloat.random(in: 40...80))
                        .offset(
                            x: CGFloat.random(in: -150...150),
                            y: CGFloat.random(in: -200...200)
                        )
                        .animation(
                            .easeInOut(duration: Double.random(in: 3...5))
                            .repeatForever(autoreverses: true)
                            .delay(Double(i) * 0.8),
                            value: headerAnimated
                        )
                }
                
                VStack(spacing: 0) {
                    // Header with progress
                    VStack(spacing: 24) {
                        // Progress bar
                        VStack(spacing: 8) {
                            HStack {
                                Text("Step 2 of 2")
                                    .font(.custom("IBMPlexSans-Regular", size: 14))
                                    .foregroundColor(.gray)
                                Spacer()
                                Text("Almost done!")
                                    .font(.custom("IBMPlexSans-Medium", size: 14))
                                    .foregroundColor(Color(red: 0.54, green: 0.17, blue: 0.22))
                            }
                            
                            GeometryReader { progressGeometry in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(height: 4)
                                    
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    Color(red: 0.54, green: 0.17, blue: 0.22),
                                                    Color(red: 0.64, green: 0.27, blue: 0.32)
                                                ],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(width: progressGeometry.size.width * progressValue, height: 4)
                                        .animation(.easeInOut(duration: 0.8).delay(0.5), value: progressValue)
                                }
                            }
                            .frame(height: 4)
                        }
                        .opacity(headerAnimated ? 1.0 : 0.0)
                        .offset(y: headerAnimated ? 0 : -20)
                        .animation(.easeOut(duration: 0.8).delay(0.2), value: headerAnimated)
                        
                        // Title section
                        VStack(spacing: 16) {
                            // Animated icon
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color(red: 0.54, green: 0.17, blue: 0.22).opacity(0.1),
                                                Color(red: 0.64, green: 0.27, blue: 0.32).opacity(0.05)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 80, height: 80)
                                
                                Image(systemName: "person.crop.circle.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(Color(red: 0.54, green: 0.17, blue: 0.22))
                                    .scaleEffect(headerAnimated ? 1.0 : 0.5)
                                    .animation(.spring(response: 0.8, dampingFraction: 0.6).delay(0.4), value: headerAnimated)
                            }
                            
                            VStack(spacing: 8) {
                                Text("Tell us about yourself")
                                    .font(.custom("IBMPlexSans-Medium", size: 32))
                                    .foregroundColor(.black)
                                    .multilineTextAlignment(.center)
                                
                                Text("We'll personalize your experience to find the perfect fits")
                                    .font(.custom("IBMPlexSans-Regular", size: 16))
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 20)
                            }
                            .opacity(headerAnimated ? 1.0 : 0.0)
                            .offset(y: headerAnimated ? 0 : 30)
                            .animation(.easeOut(duration: 0.8).delay(0.6), value: headerAnimated)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 60)
                    
                    Spacer()
                    
                    // Content cards
                    VStack(spacing: 24) {
                        // Size selection card
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
                                            
                                            // Haptic feedback
                                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                            impactFeedback.impactOccurred()
                                        }
                                    )
                                }
                            }
                        }
                        
                        // Location card
                        PreferenceCard(
                            icon: "location.fill",
                            title: "Your Region",
                            subtitle: "Where should we search for items?",
                            isAnimated: locationAnimated
                        ) {
                            VStack(spacing: 16) {
                                // Location toggle with custom style
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Use my location")
                                            .font(.custom("IBMPlexSans-Medium", size: 16))
                                            .foregroundColor(.black)
                                        
                                        Text("Automatically detect your country")
                                            .font(.custom("IBMPlexSans-Regular", size: 14))
                                            .foregroundColor(.gray)
                                    }
                                    
                                    Spacer()
                                    
                                    Toggle("", isOn: $useLocation)
                                                                                 .toggleStyle(CustomToggleStyle())
                                         .onChange(of: useLocation) { newValue in
                                             if newValue {
                                                 handleLocationToggle()
                                             } else {
                                                 selectedCountryCode = "US"
                                             }
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
                    }
                    .padding(.horizontal, 24)
                    
                    Spacer()
                    
                    // Bottom action area
                    VStack(spacing: 16) {
                        Button(action: savePreferences) {
                            HStack(spacing: 12) {
                                Text("Complete Setup")
                                    .font(.custom("IBMPlexSans-Medium", size: 18))
                                
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 16, weight: .medium))
                                    .offset(x: buttonAnimated ? 5 : 0)
                                    .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: buttonAnimated)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.54, green: 0.17, blue: 0.22),
                                        Color(red: 0.64, green: 0.27, blue: 0.32)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(28)
                            .shadow(color: Color(red: 0.54, green: 0.17, blue: 0.22).opacity(0.3), radius: 10, x: 0, y: 5)
                        }
                        .buttonStyle(PressableButtonStyle())
                        .scaleEffect(buttonAnimated ? 1.0 : 0.9)
                        .opacity(buttonAnimated ? 1.0 : 0.0)
                        .animation(.spring(response: 0.8, dampingFraction: 0.6).delay(1.8), value: buttonAnimated)
                        
                        Button("Skip for now") {
                            savePreferences()
                        }
                        .font(.custom("IBMPlexSans-Regular", size: 16))
                        .foregroundColor(.gray)
                        .opacity(buttonAnimated ? 1.0 : 0.0)
                        .animation(.easeOut(duration: 0.8).delay(2.0), value: buttonAnimated)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
            }
        }
        .onAppear {
            setupInitialValues()
            triggerAnimations()
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
    
    private func setupInitialValues() {
        selectedSize = appState.userSize
        selectedCountryCode = appState.userCountry
    }
    
    private func triggerAnimations() {
        withAnimation {
            headerAnimated = true
            progressValue = 1.0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation {
                sizeAnimated = true
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation {
                locationAnimated = true
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation {
                buttonAnimated = true
            }
        }
    }
    
    private func handleLocationToggle() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
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
    }
    
    private func savePreferences() {
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        appState.userSize = selectedSize
        appState.userCountry = selectedCountryCode
        appState.locationPermissionGranted = locationService.authorizationStatus == .authorizedWhenInUse || locationService.authorizationStatus == .authorizedAlways
        appState.saveUserPreferences()
    }
}

// MARK: - Custom Components

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

struct CountryPickerSheet: View {
    @Binding var selectedCountryCode: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List(LocationService.supportedCountries, id: \.code) { country in
                Button(action: {
                    selectedCountryCode = country.code
                    dismiss()
                }) {
                    HStack {
                        Text(country.name)
                            .foregroundColor(.primary)
                        Spacer()
                        if selectedCountryCode == country.code {
                            Image(systemName: "checkmark")
                                .foregroundColor(Color(red: 0.54, green: 0.17, blue: 0.22))
                        }
                    }
                }
            }
            .navigationTitle("Select Country")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    UserPreferencesView()
        .environmentObject(AppState())
} 