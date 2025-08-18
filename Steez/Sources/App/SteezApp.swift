import SwiftUI
import UserNotifications
import Foundation
import Supabase
import FirebaseCore
import RealmSwift

class AppDelegate: NSObject, UIApplicationDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    FirebaseApp.configure()
    return true
  }
}

@main
struct SteezApp: SwiftUI.App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var appState = AppState()
    
    init() {
        // Request notification permission
        // requestNotificationPermission()
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
    
    // private func requestNotificationPermission() {
    //     UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
    //         if granted {
    //             print("Notification permission granted")
    //         } else if let error = error {
    //             print("Error requesting notification permission: \(error)")
    //         }
    //     }
    // }
    
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
    
    // For job polling from Share Extension
    @Published var isPollingForJob: Bool = false
    @Published var pollingJobId: String? = nil
    @Published var jobErrorMessage: String? = nil
    @Published var jobFrames: [URL] = []

    // For photo uploads, to be reset
    @Published var uploadedFilename: String? = nil
    @Published var uploadedImageUrl: URL? = nil
    
    // State for the active import session
    @Published var importUploadedImageUrl: URL? = nil
    @Published var importSegmentedResults: SegmentedResults?
    @Published var importLensProducts: [LensProduct] = []
    @Published var importJobFrames: [URL] = []
    
    // Wardrobe state
    @Published var wardrobeItems: [WardrobeItem] = []
    private var wardrobeToken: NotificationToken?
    
    private let appGroupId = "group.com.steez.app"
    private let latestJobIdKey = "latest_job_id"
    private var pollingTimer: Timer?
    
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
        
        // Listen for when the app becomes active to check for pending jobs
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(checkForPendingJob),
            name: UIScene.didActivateNotification,
            object: nil
        )
        
        // Fetch initial wardrobe items
        fetchWardrobeItems()
    }
    
    deinit {
        authStateTask?.cancel()
        pollingTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
        wardrobeToken?.invalidate()
    }

    // MARK: - Wardrobe
    
    private func fetchWardrobeItems() {
        let results = WardrobeService.shared.fetchAllItems()
        self.wardrobeToken = results.observe { [weak self] (changes: RealmCollectionChange) in
            guard let self = self else { return }
            self.wardrobeItems = Array(results)
        }
    }

    // MARK: - Job Polling Logic
    
    @objc func checkForPendingJob() {
        guard let userDefaults = UserDefaults(suiteName: appGroupId) else {
            print("Could not access shared UserDefaults.")
            return
        }
        
        // Check if there is a job ID from the Share Extension
        if let jobId = userDefaults.string(forKey: latestJobIdKey) {
            print("Found pending job ID from Share Extension: \(jobId)")
            // Remove the key so we don't process the same job again
            userDefaults.removeObject(forKey: latestJobIdKey)
            
            // Start polling for this job's status
            startPolling(for: jobId)
        }
    }
    
    private func startPolling(for jobId: String) {
        // Reset state before starting
        resetPollingState()
        
        self.pollingJobId = jobId
        self.isPollingForJob = true
        
        // Invalidate any existing timer
        pollingTimer?.invalidate()
        
        // Start a new timer that fires every 3 seconds
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.pollJobStatus(jobId: jobId)
        }
    }

    private func pollJobStatus(jobId: String) {
        NetworkService.shared.getJobStatus(jobId: jobId) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let response):
                print("Polled job \(jobId), status: \(response.status.rawValue)")
                switch response.status {
                case .SELECTING_FRAMES:
                    // Success case! Frames are ready.
                    if let frameUrls = response.selected_frame_urls, !frameUrls.isEmpty {
                        self.jobFrames = frameUrls
                        self.importJobFrames = frameUrls
                        self.stopPolling()
                    }
                    // If URLs are missing, we keep polling, maybe they're not saved yet.
                    
                case .FAILED:
                    // The job failed on the backend.
                    self.jobErrorMessage = response.error_message ?? "The video processing job failed."
                    self.stopPolling()
                    
                case .PENDING, .PROCESSING:
                    // The job is still in progress, do nothing and let the timer fire again.
                    break
                    
                case .COMPLETE:
                    // This case shouldn't be hit if the flow is correct,
                    // but we handle it just in case.
                    self.jobErrorMessage = "Job was already completed."
                    self.stopPolling()
                }
                
            case .failure(let error):
                // The network request itself failed.
                self.jobErrorMessage = "Failed to get job status: \(error.localizedDescription)"
                self.stopPolling()
            }
        }
    }
    
    private func stopPolling() {
        pollingTimer?.invalidate()
        pollingTimer = nil
        isPollingForJob = false
    }

    private func resetPollingState() {
        stopPolling()
        pollingJobId = nil
        jobErrorMessage = nil
        jobFrames = []
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
        resetPollingState()
    }

    // MARK: - Centralized Reset for UI State

    func fullReset() {
        // This function provides a single point to reset the temporary state
        // for the import screen, without clearing the main wardrobe/recent activity.
        importUploadedImageUrl = nil
        importSegmentedResults = nil
        importLensProducts = []
        importJobFrames = []
        
        // Also reset polling state for the import view
        resetPollingState()
    }

    // MARK: - Helper used by UI to reset analysis results
    func clearResults() {
        segmentedResults = nil
        lensProducts = []
        selectedSegmentIndex = 0
        uploadedFilename = nil
        uploadedImageUrl = nil
        
        // Also clear the import-specific state
        importUploadedImageUrl = nil
        importSegmentedResults = nil
        importLensProducts = []
        importJobFrames = []

        resetPollingState()
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
 
