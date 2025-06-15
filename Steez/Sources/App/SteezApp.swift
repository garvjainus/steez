import SwiftUI
import UserNotifications

@main
struct SteezApp: App {
    @StateObject private var appState = AppState()
    
    init() {
        // Request notification permission
        requestNotificationPermission()
    }
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                if appState.hasCompletedOnboarding {
                    // User has completed both feature overview and preferences setup
                    ContentView()
                        .environmentObject(appState)
                        .onAppear {
                            // Check server when app appears
                            appState.checkServerAvailability()
                        }
                } else if appState.hasSeenOnboarding {
                    // User has seen the feature overview, now show preferences setup
                    UserPreferencesView()
                        .environmentObject(appState)
                } else {
                    // First time user, show feature overview
                    LandingPageView()
                        .environmentObject(appState)
                }
            }
        }
    }
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                print("Notification permission granted")
            } else if let error = error {
                print("Error requesting notification permission: \(error)")
            }
        }
    }
}

class AppState: ObservableObject {
    @Published var isProcessing: Bool = false
    @Published var currentUser: User?
    @Published var isServerAvailable: Bool = false
    @Published var errorMessage: String? = nil
    @Published var hasSeenOnboarding: Bool = false
    @Published var hasUserPreferences: Bool = false
    @Published var hasCompletedOnboarding: Bool = false
    
    // User preferences
    @Published var userSize: String = "M"
    @Published var userCountry: String = "US"
    @Published var locationPermissionGranted: Bool = false
    
    // For Google Lens Analysis (backward compatibility)
    @Published var lensProducts: [LensProduct] = []
    @Published var isAnalyzingWithLens: Bool = false
    
    // For new segmented results
    @Published var segmentedResults: SegmentedResults?
    @Published var selectedSegmentIndex: Int = 0
    
    init() {
        // Check if user has seen onboarding
        self.hasSeenOnboarding = UserDefaults.standard.bool(forKey: "hasSeenOnboarding")
        
        // Check if user has set preferences
        self.hasUserPreferences = UserDefaults.standard.bool(forKey: "hasUserPreferences")
        
        // User has completed onboarding if they've seen it AND set preferences
        self.hasCompletedOnboarding = hasSeenOnboarding && hasUserPreferences
        
        // Load user preferences if they exist
        if hasUserPreferences {
            self.userSize = UserDefaults.standard.string(forKey: "userSize") ?? "M"
            self.userCountry = UserDefaults.standard.string(forKey: "userCountry") ?? "US"
            self.locationPermissionGranted = UserDefaults.standard.bool(forKey: "locationPermissionGranted")
        }
        
        // Check server first
        checkServerAvailability()
    }
    
    func completeOnboarding() {
        hasSeenOnboarding = true
        UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
        // Update completed onboarding status
        hasCompletedOnboarding = hasSeenOnboarding && hasUserPreferences
    }
    
    func resetOnboarding() {
        hasSeenOnboarding = false
        hasUserPreferences = false
        hasCompletedOnboarding = false
        UserDefaults.standard.set(false, forKey: "hasSeenOnboarding")
        UserDefaults.standard.removeObject(forKey: "hasUserPreferences")
        resetUserPreferences()
    }
    
    func saveUserPreferences() {
        hasUserPreferences = true
        UserDefaults.standard.set(true, forKey: "hasUserPreferences")
        UserDefaults.standard.set(userSize, forKey: "userSize")
        UserDefaults.standard.set(userCountry, forKey: "userCountry")
        UserDefaults.standard.set(locationPermissionGranted, forKey: "locationPermissionGranted")
        
        // Update completed onboarding status
        hasCompletedOnboarding = hasSeenOnboarding && hasUserPreferences
    }
    
    func resetUserPreferences() {
        hasUserPreferences = false
        UserDefaults.standard.removeObject(forKey: "hasUserPreferences")
        UserDefaults.standard.removeObject(forKey: "userSize")
        UserDefaults.standard.removeObject(forKey: "userCountry")
        UserDefaults.standard.removeObject(forKey: "locationPermissionGranted")
        userSize = "M"
        userCountry = "US"
        locationPermissionGranted = false
    }
    
    func clearResults() {
        lensProducts = []
        segmentedResults = nil
        selectedSegmentIndex = 0
    }
    
    func checkServerAvailability() {
        errorMessage = nil
        
        NetworkService.shared.checkServerAvailability { [weak self] isAvailable in
            DispatchQueue.main.async {
                self?.isServerAvailable = isAvailable
                
                if isAvailable {
                    print("Server is available.")
                } else {
                    self?.errorMessage = "Cannot connect to the server. Please make sure the backend is running and try again."
                }
            }
        }
    }
    
    // Methods for handling user authentication
    func signIn(email: String, password: String, completion: @escaping (Bool) -> Void) {
        // In a real app, this would use Firebase Auth or similar
        // Mock implementation for now
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.currentUser = User(userId: UUID(), email: email, plan: .free)
            completion(true)
        }
    }
    
    func signOut() {
        currentUser = nil
    }
}

struct User {
    let userId: UUID
    let email: String
    let plan: Plan
    
    enum Plan: String {
        case free, pro
    }
} 
 