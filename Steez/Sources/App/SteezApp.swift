import SwiftUI
import UserNotifications
import Foundation
import Supabase

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
                    // User has completed all steps
                    ContentView()
                        .environmentObject(appState)
                } else if appState.isAuthenticated {
                    // User is authenticated, but needs to set preferences
                    UserPreferencesView()
                        .environmentObject(appState)
                } else if appState.hasSeenOnboarding {
                    // User has seen landing page, needs to sign in/up
                    AuthView()
                        .environmentObject(appState)
                } else {
                    // First time user
                    LandingPageView()
                        .environmentObject(appState)
                }
            }
            .onOpenURL { url in
                handleDeepLink(url: url)
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
    
    private func handleDeepLink(url: URL) {
        // Handle auth callback URLs
        if url.scheme == "steez" && url.host == "auth-callback" {
            // Parse the URL parameters
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            if let queryItems = components?.queryItems {
                // Handle the authentication result
                print("Received auth callback: \(url)")
                // The auth state listener in AppState will automatically handle the session
            }
        }
    }
}

class AppState: ObservableObject {
    @Published var isProcessing: Bool = false
    @Published var currentUser: LocalUser?
    @Published var isServerAvailable: Bool = false
    @Published var errorMessage: String? = nil
    
    // Onboarding State
    @Published var hasSeenOnboarding: Bool = false
    @Published var isAuthenticated: Bool = false
    @Published var hasSetPreferences: Bool = false
    
    // Combined state for main view logic
    @Published var hasCompletedOnboarding: Bool = false

    // User preferences
    @Published var userSize: String = "M"
    @Published var userCountry: String = "US"
    @Published var locationPermissionGranted: Bool = false
    
    // For Google Lens Analysis (backward compatibility)
    @Published var lensProducts: [LensProduct] = []
    
    // For new segmented results
    @Published var segmentedResults: SegmentedResults?
    @Published var selectedSegmentIndex: Int = 0
    
    private var authStateTask: Task<Void, Never>?

    init() {
        // Check user's progress through onboarding
        self.hasSeenOnboarding = UserDefaults.standard.bool(forKey: "hasSeenOnboarding")
        self.hasSetPreferences = UserDefaults.standard.bool(forKey: "hasUserPreferences")
        
        // Start listening for auth changes
        listenToAuthChanges()

        // Load user preferences if they exist
        if hasSetPreferences {
            self.userSize = UserDefaults.standard.string(forKey: "userSize") ?? "M"
            self.userCountry = UserDefaults.standard.string(forKey: "userCountry") ?? "US"
            self.locationPermissionGranted = UserDefaults.standard.bool(forKey: "locationPermissionGranted")
        }
        
        // Check server first
        checkServerAvailability()
    }
    
    deinit {
        authStateTask?.cancel()
    }

    private func listenToAuthChanges() {
        authStateTask = Task {
            for await (event, session) in SupabaseService.shared.listenToAuthEvents() {
                await MainActor.run {
                    switch event {
                    case .initialSession, .signedIn:
                        if let supa = session?.user {
                            self.currentUser = LocalUser(userId: supa.id, email: supa.email ?? "", plan: .free)
                            self.isAuthenticated = true
                        }
                    case .signedOut:
                        self.currentUser = nil
                        self.isAuthenticated = false
                    case .passwordRecovery, .tokenRefreshed, .userUpdated:
                        break
                    default:
                        break
                    }
                    updateOnboardingCompletion()
                }
            }
        }
    }

    func completeLanding() {
        hasSeenOnboarding = true
        UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
        updateOnboardingCompletion()
    }
    
    func saveUserPreferences() {
        hasSetPreferences = true
        UserDefaults.standard.set(true, forKey: "hasUserPreferences")
        UserDefaults.standard.set(userSize, forKey: "userSize")
        UserDefaults.standard.set(userCountry, forKey: "userCountry")
        UserDefaults.standard.set(locationPermissionGranted, forKey: "locationPermissionGranted")
        updateOnboardingCompletion()
    }
    
    func resetOnboarding() {
        hasSeenOnboarding = false
        isAuthenticated = false
        hasSetPreferences = false
        
        UserDefaults.standard.set(false, forKey: "hasSeenOnboarding")
        UserDefaults.standard.set(false, forKey: "isAuthenticated")
        UserDefaults.standard.removeObject(forKey: "hasUserPreferences")
        
        // Also sign out from Supabase
        Task {
            try? await SupabaseService.shared.signOut()
        }

        resetUserPreferences()
        updateOnboardingCompletion()
    }
    
    private func updateOnboardingCompletion() {
        hasCompletedOnboarding = hasSeenOnboarding && isAuthenticated && hasSetPreferences
        lensProducts = []
        segmentedResults = nil
        selectedSegmentIndex = 0
    }

    // MARK: - Helper used by UI to reset analysis results
    func clearResults() {
        lensProducts = []
        segmentedResults = nil
        selectedSegmentIndex = 0
    }

    func resetUserPreferences() {
        hasSetPreferences = false
        UserDefaults.standard.removeObject(forKey: "hasUserPreferences")
        UserDefaults.standard.removeObject(forKey: "userSize")
        UserDefaults.standard.removeObject(forKey: "userCountry")
        UserDefaults.standard.removeObject(forKey: "locationPermissionGranted")
        userSize = "M"
        userCountry = "US"
        locationPermissionGranted = false
    }
    
    func checkServerAvailability() {
        NetworkService.shared.checkServerAvailability { isAvailable in
            DispatchQueue.main.async {
                self.isServerAvailable = isAvailable
                
                if isAvailable {
                    print("Server is available.")
                } else {
                    self.errorMessage = "Cannot connect to the server. Please make sure the backend is running and try again."
                }
            }
        }
    }
    
    // Methods for handling user authentication
    func signIn(email: String, password: String, completion: @escaping (Bool) -> Void) {
        // In a real app, this would use Firebase Auth or similar
        // Mock implementation for now
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.currentUser = LocalUser(userId: UUID(), email: email, plan: .free)
            completion(true)
        }
    }
    
    func signOut() {
        currentUser = nil
    }
}

struct LocalUser {
    let userId: UUID
    let email: String
    let plan: Plan
    
    enum Plan: String {
        case free, pro
    }
} 
 
