import SwiftUI
import PhotosUI
import UserNotifications
import UIKit
import CoreLocation
import Kingfisher

// MARK: - Main ContentView
struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab: Int = 1 // Start with Import tab (index 1)
    @State private var tabBarOffset: CGFloat = 0
    
    var body: some View {
        GeometryReader { geometry in
        ZStack {
                SteezColors.background
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Main Content
            TabView(selection: $selectedTab) { // Uses Int binding
                        WardrobeView(selectedTab: $selectedTab) // Pass binding
                    .tag(0)
                        
                        MainImportView()
                            .tag(1)
                            .onAppear {
                                Task {
                                    await appState.refreshUsageQuota()
                                }
                            }
                
                ProfileView()
                            .tag(2)
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                    
                    // Custom Tab Bar
                    CustomTabBar(selectedTab: $selectedTab) // Pass Int binding
                        .offset(y: tabBarOffset)
                        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: tabBarOffset)
            }
            
                // Overlay for server errors
            if let errorMessage = appState.errorMessage {
                    serverErrorOverlay(message: errorMessage)
            }
        }
        .sheet(isPresented: $appState.showingPaywall) {
            PaywallView(context: appState.paywallContext) {
                // Dismiss handler
                appState.showingPaywall = false
            }
        }
        }
    }
    
    private func serverErrorOverlay(message: String) -> some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    appState.errorMessage = nil
                }
            
            VStack(spacing: 20) {
                Image(systemName: "wifi.exclamationmark")
                    .font(.system(size: 50, weight: .light))
                    .foregroundColor(SteezColors.error)
            
                Text("Connection Issue")
                    .font(SteezFonts.medium(22))
                    .foregroundColor(SteezColors.textPrimary)
            
            Text(message)
                    .font(SteezFonts.regular(16))
                    .foregroundColor(SteezColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
                HStack(spacing: 12) {
                    Button("Dismiss") {
                        appState.errorMessage = nil
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    
                    Button("Retry") {
                appState.checkServerAvailability()
                    }
                    .buttonStyle(PrimaryButtonStyle())
            }
        }
            .padding(32)
        .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(SteezColors.cardBackground)
                    .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
        )
        .padding(32)
    }
}
}

// MARK: - Custom Tab Bar
// duplicate definitions removed to avoid redeclaration errors




// MARK: - Import View (Redesigned)
struct MainImportView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingImagePicker = false
    @State private var showingCamera = false
    @State private var showingLinkInput = false
    @State private var selectedMedia: [PHPickerResult]?
    @State private var capturedImage: UIImage?
    @State private var showingAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var uploadProgress: Float = 0
    @State private var isUploading = false
    @State private var retryData: UIImage? = nil
    @State private var retryAttempts = 0
    @State private var currentUploadUserId: String?
    @State private var animateContent = false
    
    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 32) {
                    // Header
                    VStack(spacing: 8) {
                        Text("Import Style")
                            .font(SteezFonts.medium(32))
                            .foregroundColor(SteezColors.textPrimary)
                        
                        Text("Add photos or videos to discover similar items")
                            .font(SteezFonts.regular(16))
                            .foregroundColor(SteezColors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .opacity(animateContent ? 1 : 0)
                    .offset(y: animateContent ? 0 : -20)
                    
                    // Main Content
                    VStack(spacing: 24) {
                        if appState.isProcessing || isUploading {
                            ProcessingView(
                                isUploading: isUploading,
                                uploadProgress: uploadProgress
                            )
                        } else if let retryData = retryData, appState.uploadedFilename == nil {
                            RetryUploadView(
                                image: retryData,
                                onRetry: {
                                    if let userId = currentUploadUserId {
                                        processImage(retryData, userId: userId)
                                    }
                                }
                            )
                        } else if let imageUrl = appState.importUploadedImageUrl {
                            UploadedImageView(imageUrl: imageUrl)
                        } else {
                            ImportOptionsView(
                                onCameraAction: { showingCamera = true },
                                onPhotoLibraryAction: { showingImagePicker = true },
                                onLinkAction: { showingLinkInput = true }
                            )
                        }
                        
                        // Status Indicators
                        VStack(spacing: 16) {
                            // Job polling indicator removed for now
                            
                            if !appState.importJobFrames.isEmpty {
                                FrameSelectorView(frameUrls: appState.importJobFrames) { selectedUrl in
                                    // Handle frame selection here
                                }
                            }
                        }
                        
                        // Results
                        VStack(spacing: 24) {
                            if !appState.importLensProducts.isEmpty {
                                Button("Start New Analysis") {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                        appState.fullReset()
                                    }
                                }
                                .buttonStyle(PrimaryButtonStyle())
                                .padding(.top, 8)
                                LensResultsDisplay(lensProducts: appState.importLensProducts)
                            }
                        }
                }
                    .padding(.horizontal, 24)
                    .opacity(animateContent ? 1 : 0)
                    .offset(y: animateContent ? 0 : 30)
                    
                    Spacer(minLength: 100)
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                animateContent = true
            }
                }
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(selectedMedia: $selectedMedia)
            }
            .fullScreenCover(isPresented: $showingCamera) {
                CameraPicker(selectedImage: $capturedImage)
            }
        .sheet(isPresented: $showingLinkInput) {
            Text("Link input coming soon...")
                .padding()
                .environmentObject(appState)
            }
            .onChange(of: selectedMedia) { newValue in
                if let results = newValue, !results.isEmpty {
                    processSelectedMedia(results)
                }
            }
            .onChange(of: capturedImage) { newImage in
                if let image = newImage {
                    startImageProcessing(image)
                }
            }
            .alert(isPresented: $showingAlert) {
                Alert(
                    title: Text(alertTitle),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
    }
    
    // MARK: - Processing Methods
    
    private func startImageProcessing(_ image: UIImage) {
        self.retryData = image
        
        // Check authentication first
        guard let userId = appState.currentUser?.userId.uuidString else {
            self.showError("Authentication Error", "Please sign in to upload images.")
            return
        }
        
        // Check quota before processing
        Task {
            let canUpload = await appState.canPerformAction(.upload)
            if canUpload {
                await MainActor.run {
                    self.currentUploadUserId = userId
                    self.processImage(image, userId: userId)
                }
            }
            // If can't upload, paywall is automatically shown by canPerformAction
        }
    }
    
    private func processSelectedMedia(_ results: [PHPickerResult]) {
        guard let result = results.first else { return }
        
        result.itemProvider.loadObject(ofClass: UIImage.self) { object, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.showError("Loading Error", "Failed to load selected image: \(error.localizedDescription)")
                    return
                }
                
                guard let image = object as? UIImage else {
                    self.showError("Invalid Image", "The selected item is not a valid image.")
                    return
                }
                
                startImageProcessing(image)
            }
        }
    
        self.selectedMedia = nil
    }
    
    private func processImage(_ image: UIImage, userId: String) {
        let observer = NotificationCenter.default.addObserver(
            forName: .uploadProgressNotification,
            object: nil,
            queue: .main
        ) { notification in
            if let progress = notification.userInfo?["progress"] as? Float {
                self.isUploading = true
                self.uploadProgress = progress
            }
        }
        
        appState.isProcessing = true
        self.isUploading = true
        self.retryAttempts = 0
        appState.clearResults()

        NetworkService.shared.processImage(image, userId: userId, userSize: appState.userSize, userCountry: appState.userCountry) { result in
            DispatchQueue.main.async {
                NotificationCenter.default.removeObserver(observer)
                
                appState.isProcessing = false
                self.isUploading = false
                self.uploadProgress = 0.0
                
                switch result {
                case .success(let uploadResponse):
                    print("✅ Image uploaded via ContentView.")
                    // Save to main wardrobe
                    appState.uploadedFilename = uploadResponse.data.filename
                    appState.uploadedImageUrl = uploadResponse.data.imageUrl
                    
                    // Also set the temporary import state to show results on the current screen
                    appState.importUploadedImageUrl = uploadResponse.data.imageUrl

                    if let products = uploadResponse.data.products, !products.isEmpty {
                        appState.lensProducts = products
                        appState.importLensProducts = products
                        print("✅ Loaded \(products.count) lens products from upload response")
                    } else if let filename = uploadResponse.data.filename {
                        // Fallback: call Lens directly by filename if upload response had no products
                        NetworkService.shared.analyzeImageWithLens(filename: filename) { result in
                            DispatchQueue.main.async {
                                switch result {
                                case .success(let products):
                                    appState.lensProducts = products
                                    appState.importLensProducts = products
                                    print("✅ Loaded \(products.count) lens products via fallback analyze endpoint")
                                case .failure(let error):
                                    print("❌ Fallback Lens analyze failed: \(error)")
                                }
                            }
                        }
                    }
                    
                    self.showSuccess("Upload Complete", "Image uploaded and analyzed successfully!")
                    self.retryData = nil
                    
                case .failure(let error):
                    print("❌ Image upload failed: \(error)")
                    self.retryAttempts += 1
                    let userFriendlyMessage = NetworkService.shared.userFriendlyErrorMessage(for: error)
                    
                    if self.retryAttempts < 3 && self.retryData != nil {
                        self.showError("Upload Issue", "\(userFriendlyMessage) You can retry processing this image.")
                        } else {
                        self.showError("Upload Failed", "\(userFriendlyMessage) Multiple attempts failed.")
                        self.retryData = nil
                    }
                }
            }
        }
    }
    
    private func showError(_ title: String, _ message: String) {
        alertTitle = title
        alertMessage = message
        showingAlert = true
    }
    
    private func showSuccess(_ title: String, _ message: String) {
        alertTitle = title
        alertMessage = message
        showingAlert = true
    }
    
    @ViewBuilder
    private var frameSelector: some View {
        if !appState.jobFrames.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                Text("Select Frame")
                    .font(SteezFonts.medium(18))
                    .foregroundColor(SteezColors.textPrimary)
                
                FrameSelectorView(frameUrls: appState.jobFrames) { selectedUrl in
                    print("User selected frame URL: \(selectedUrl)")
                    appState.isProcessing = true
                    
                    KingfisherManager.shared.retrieveImage(with: selectedUrl) { result in
                        switch result {
                        case .success(let value):
                            print("Successfully downloaded selected frame as UIImage.")
                            let image = value.image
                            
                            DispatchQueue.main.async {
                                self.retryData = image
                                
                                guard let userId = appState.currentUser?.userId.uuidString else {
                                    appState.isProcessing = false
                                    self.showError("Authentication Error", "Please sign in to process images.")
                                    return
                                }
                                
                                // Check quota before processing
                                Task {
                                    let canUpload = await appState.canPerformAction(.upload)
                                    if canUpload {
                                        await MainActor.run {
                                            self.currentUploadUserId = userId
                                            self.processImage(image, userId: userId)
                                        }
                                    } else {
                                        await MainActor.run {
                                            appState.isProcessing = false
                                        }
                                    }
                                }
                            }
                        case .failure(let error):
                            DispatchQueue.main.async {
                                appState.isProcessing = false
                                print("Error downloading selected frame: \(error)")
                                self.showError("Download Error", "Failed to download the selected frame. Please try again.")
                            }
                        }
                    }
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(SteezColors.cardBackground)
                    .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 2)
            )
        }
    }
}

// MARK: - Import Options View





// MARK: - Link Input View
// duplicate definitions removed; original versions exist in ImportComponents.swift



// MARK: - Notification name for upload progress (defined in NetworkService)
