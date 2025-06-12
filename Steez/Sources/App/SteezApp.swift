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
                if appState.hasSeenOnboarding {
            ContentView()
                .environmentObject(appState)
                .onAppear {
                    // Check server when app appears
                    appState.checkServerAvailability()
                        }
                } else {
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
    
    // For Google Lens Analysis (backward compatibility)
    @Published var lensProducts: [LensProduct] = []
    @Published var isAnalyzingWithLens: Bool = false
    
    // For new segmented results
    @Published var segmentedResults: SegmentedResults?
    @Published var selectedSegmentIndex: Int = 0
    

    
    init() {
        // Check if user has seen onboarding
        self.hasSeenOnboarding = UserDefaults.standard.bool(forKey: "hasSeenOnboarding")
        
        // Check server first
        checkServerAvailability()
    }
    
    func completeOnboarding() {
        hasSeenOnboarding = true
        UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
    }
    
    func resetOnboarding() {
        hasSeenOnboarding = false
        UserDefaults.standard.set(false, forKey: "hasSeenOnboarding")
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
 