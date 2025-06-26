import SwiftUI
import PhotosUI
import UserNotifications
import UIKit
import CoreLocation

// MARK: - Main ContentView

struct ContentView: View {
    @State private var selectedTab = 0
    @EnvironmentObject var appState: AppState
    @State private var showingPreferences = false
    
    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                ImportView()
                    .tabItem {
                        Label("Import", systemImage: "square.and.arrow.down")
                    }
                    .tag(0)
                
                ProfileView()
                    .tabItem {
                        Label("Profile", systemImage: "person")
                    }
                    .tag(1)
            }
            
            // Server error overlay
            if let errorMessage = appState.errorMessage {
                serverErrorView(message: errorMessage)
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingPreferences = true }) {
                    Image(systemName: "gearshape.fill")
                        .foregroundColor(.blue)
                }
            }
        }
        .sheet(isPresented: $showingPreferences) {
            UserPreferencesView()
                .environmentObject(appState)
        }
    }
    
    private func serverErrorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundColor(.yellow)
            
            Text("Connection Error")
                .font(.headline)
            
            Text(message)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(action: {
                appState.checkServerAvailability()
            }) {
                Text("Retry Connection")
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .padding(.top, 8)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(radius: 10)
        )
        .padding(32)
    }
}

struct ImportView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingImagePicker = false
    @State private var showingShareSheet = false
    @State private var selectedMedia: [PHPickerResult]?
    @State private var showingAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var uploadProgress: Float = 0
    @State private var isUploading = false
    @State private var retryData: UIImage? = nil
    @State private var retryAttempts = 0
    @State private var uploadedFilename: String?
    @State private var uploadedImageUrl: URL?
    @State private var currentUploadUserId: String?
    
    private var buttons: some View {
        VStack(spacing: 20){
            Button(action: { showingImagePicker = true}) {
                    ImportButtonView(title: "Import from Camera", systemImage: "camera")
                }
            Button(action: {showingShareSheet = true }) {
                ImportButtonView(title:"Import from Social", systemImage: "square.and.arrow.down")
                }
        }
    }
    
    private var inProgress: some View {
        Group {
                if appState.isProcessing || isUploading {
                    VStack(spacing: 10) {
                        if isUploading {
                            ProgressView(value: uploadProgress)
                            .padding()
                    }
                    if appState.isProcessing {
                        Text("Processing…")
                                .font(.caption)
                                .foregroundColor(.secondary)
                    }
                }
            }          // when the condition is false, Group implicitly
                       // supplies `EmpuserfrityView()`, so no explicit `else`
        }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                ScrollView {
                    VStack(spacing: 20) {
                        if appState.isProcessing || isUploading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .padding()
                            
                            if isUploading {
                                VStack {
                                    Text("Uploading...")
                                    ProgressView(value: uploadProgress)
                                        .progressViewStyle(LinearProgressViewStyle())
                                        .padding()
                                    Text("\(Int(uploadProgress * 100))%")
                    }
                    .padding()
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(10)
                    .padding(.horizontal)
                }
                        } else if let retryData = retryData, uploadedFilename == nil {
                            // The image was not successfully uploaded
                            VStack {
                                Image(uiImage: retryData)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxHeight: 300)
                        .cornerRadius(8)
                                    .padding()
                                
                                Button("Try Upload Again") {
                                    if let userId = currentUploadUserId {
                                        processImage(retryData, userId: userId)
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .padding()
                        }
                        } else if uploadedImageUrl != nil {
                            uploadedImageView
                        } else {
                            buttons
                        }
                        
                        lensProgressIndicator
                        segmentedResultsDisplay
                        lensResultsDisplay
                }
                    .padding()
                }
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(selectedMedia: $selectedMedia)
            }
            .onChange(of: selectedMedia) { newValue in
                if let results = newValue, !results.isEmpty {
                    processSelectedMedia(results)
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
            .navigationTitle("Import Items")
        }
    }
    
    // --- Segmented Results Display ---
    @ViewBuilder
    private var segmentedResultsDisplay: some View {
        if let segmentedResults = appState.segmentedResults, !segmentedResults.segments.isEmpty {
            VStack(alignment: .leading, spacing: 15) {
                Text("Detected Clothing Items")
                    .font(.headline)
                    .padding(.horizontal)
                
                // Tab selector for different clothing items
                if segmentedResults.segments.count > 1 {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(Array(segmentedResults.segments.enumerated()), id: \.offset) { index, segment in
                                Button(action: {
                                    appState.selectedSegmentIndex = index
                                }) {
                                    VStack(spacing: 4) {
                                        Text(segment.itemType.capitalized)
                                            .font(.caption)
                                            .fontWeight(.medium)
                                        
                                        Text(String(format: "%.0f%%", segment.confidence * 100))
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(appState.selectedSegmentIndex == index ? Color.blue : Color.gray.opacity(0.2))
                                    )
                                    .foregroundColor(appState.selectedSegmentIndex == index ? .white : .primary)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .accessibilityLabel("\(segment.itemType) with \(String(format: "%.0f", segment.confidence * 100))% confidence")
                                .accessibilityHint("Tap to view eBay results for this item")
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                
                // Display results for selected segment
                if appState.selectedSegmentIndex < segmentedResults.segments.count,
                   appState.selectedSegmentIndex >= 0 {
                    let selectedSegment = segmentedResults.segments[appState.selectedSegmentIndex]
                    
                    VStack(alignment: .leading, spacing: 10) {
                        // Segment info
                        HStack {
                            Text(selectedSegment.phrase)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Spacer()
                            
                            Text("\(String(format: "%.0f", selectedSegment.confidence * 100))% confident")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.green.opacity(0.2))
                                .foregroundColor(.green)
                                .cornerRadius(6)
                        }
                        .padding(.horizontal)
                        
                        // eBay results for this segment
                        if selectedSegment.ebayResults.isEmpty {
                            Text("No eBay results found for this item")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                                .padding(.vertical, 8)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                                .padding(.horizontal)
                        } else {
                            EbayMatchesView(matches: selectedSegment.ebayResults)
                        }
                    }
                }
            }
            .padding(.vertical)
        }
    }

    // --- Original Lens Progress and Results (Backward Compatibility) ---
    @ViewBuilder
    private var lensProgressIndicator: some View {
        if appState.isProcessing {
            ProgressView("Analyzing image with AI...")
                .padding()
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(10)
                .padding(.horizontal)
        }
    }

    @ViewBuilder
    private var lensResultsDisplay: some View {
        if !appState.lensProducts.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Google Lens Suggestions")
                    .font(.headline)
                    .padding(.horizontal)
                
                ForEach(appState.lensProducts) { product in
                    LensProductRow(product: product)
                }
            }
            .padding(.vertical)
        }
    }

    // MARK: - Media Processing Logic (SHOULD BE INSIDE ImportView)
    func processSelectedMedia(_ results: [PHPickerResult]) {
        appState.isProcessing = true
        self.uploadedFilename = nil
        self.uploadedImageUrl = nil
        appState.clearResults() // Clear both old and new results
        self.currentUploadUserId = nil
        
        guard let result = results.first else {
            appState.isProcessing = false
            return
        }
        
        retryData = nil
        retryAttempts = 0
        
        result.itemProvider.loadObject(ofClass: UIImage.self) { (image, error) in
            DispatchQueue.main.async {
                if let error = error {
                    self.showError("Failed to load image", error.localizedDescription)
                    appState.isProcessing = false
                    return
                }
                
                guard let image = image as? UIImage else {
                    self.showError("Invalid Image", "Could not process the selected image.")
                    appState.isProcessing = false
                    return
                }
                
                self.retryData = image
                
                let demoUserId = appState.currentUser?.userId.uuidString ?? "demo-user-swift"
                self.currentUploadUserId = demoUserId
                self.processImage(image, userId: demoUserId)
            }
        }
    }
    
    func processImage(_ image: UIImage, userId: String) {
        // Track upload progress
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
        self.retryAttempts = 0 // Reset retry attempts for new processing
        self.uploadedFilename = nil
        self.uploadedImageUrl = nil
        appState.clearResults()

        NetworkService.shared.processImage(image, userId: userId, userSize: appState.userSize, userCountry: appState.userCountry) { result in
            DispatchQueue.main.async {
                // Remove the observer when done
                NotificationCenter.default.removeObserver(observer)
                
                appState.isProcessing = false
                self.isUploading = false
                self.uploadProgress = 0.0
                
                switch result {
                case .success(let uploadResponse):
                    print("✅ Image uploaded via ContentView.")
                    self.uploadedFilename = uploadResponse.data.filename
                    self.uploadedImageUrl = uploadResponse.data.imageUrl
                    
                    // Handle new segmented results
                    if let segmentedResults = uploadResponse.data.segmentedResults {
                        appState.segmentedResults = segmentedResults
                        appState.selectedSegmentIndex = 0
                        print("✅ Loaded \(segmentedResults.totalItems) clothing segments from upload response")
                    }
                    
                    // Backward compatibility: Automatically set lens products if they were returned from the backend
                    if let products = uploadResponse.data.products {
                        appState.lensProducts = products
                        print("✅ Loaded \(products.count) lens products from upload response (backward compatibility)")
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
                        self.showError("Upload Failed", "\(userFriendlyMessage) Multiple attempts failed or retrying is not possible. Please check your internet connection and try again later.")
                        self.retryData = nil // Clear retry data if max attempts reached or not retryable
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
    private var uploadedImageView: some View {
        if let imageUrl = uploadedImageUrl {
            VStack {
                AsyncImage(url: imageUrl) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(height: 250)
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 250)
                            .cornerRadius(8)
                    case .failure:
                        Image(systemName: "photo")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 200)
                            .foregroundColor(.gray)
                            .overlay(
                                Text("Failed to load image")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            )
                    @unknown default:
                        EmptyView()
                    }
                }
                .padding(.horizontal)
                
                Text("Image uploaded successfully")
                .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 5)
            }
            .background(Color.secondary.opacity(0.05))
            .cornerRadius(12)
            .padding(.horizontal)
        }
    }
}

struct ImportButtonView: View {
    let title: String
    let systemImage: String
    
    var body: some View {
        HStack {
            Image(systemName: systemImage)
                .font(.title2)
            Text(title)
                .font(.headline)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.blue)
        .foregroundColor(.white)
        .cornerRadius(10)
        .padding(.horizontal)
    }
}

struct ProfileView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Account")) {
                    Text("Email")
                    Text("Plan: Free")
                }
                
                Section(header: Text("Settings")) {
                    Toggle("Price Drop Notifications", isOn: .constant(true))
                    Toggle("Out of Stock Alerts", isOn: .constant(true))
                }
                
                Section(header: Text("Debug")) {
                    Button(action: {
                        appState.resetOnboarding()
                    }) {
                        Text("Reset Onboarding")
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Profile")
        }
    }
}

// MARK: - Notification name for upload progress (defined in NetworkService)

// New View for displaying Lens Product Row
struct LensProductRow: View {
    let product: LensProduct
    @State private var showingOriginalImage = false

    var body: some View {
        VStack(spacing: 0) {
            Button(action: {
                UIApplication.shared.open(product.link)
            }) {
                HStack(spacing: 15) {
                    if let thumbnailUrl = product.thumbnailUrl {
                        AsyncImage(url: thumbnailUrl) {
                            $0.resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 80, height: 80)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                        } placeholder: {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 80, height: 80)
                                .cornerRadius(8)
                                .overlay(Image(systemName: "photo").foregroundColor(.white))
                        }
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 80, height: 80)
                            .cornerRadius(8)
                            .overlay(Image(systemName: "eyeglasses").foregroundColor(.white))
                    }
                    VStack(alignment: .leading) {
                        Text(product.title)
                            .font(.headline)
                            .lineLimit(2)
                        
                        HStack {
                            Text(product.source)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            if let category = product.category, !category.isEmpty {
                                Text("•")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(category)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        
                        if let price = product.price {
                            Text(price)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(product.extractedPrice != nil ? .green : .primary)
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.right") // Indicate tappable
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
            }
            .buttonStyle(PlainButtonStyle()) // Use PlainButtonStyle to make the whole row tappable like a NavLink

            // Add "View Original" button if imageUrl is available
            if let _ = product.imageUrl {
                Button(action: {
                    showingOriginalImage = true
                }) {
                    HStack {
                        Image(systemName: "photo")
                            .imageScale(.small)
                        Text("View Original Image")
                            .font(.caption)
                    }
                    .padding(.vertical, 5)
                    .padding(.horizontal, 10)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(15)
                }
                .padding(.top, -5)
                .padding(.bottom, 5)
                .sheet(isPresented: $showingOriginalImage) {
                    OriginalImageView(imageUrl: product.imageUrl!)
                }
            }
        }
        .padding(.horizontal)
    }
}

// View for displaying the original image
struct OriginalImageView: View {
    let imageUrl: URL
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            VStack {
                AsyncImage(url: imageUrl) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .padding()
                    case .failure:
                        VStack {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.largeTitle)
                                .foregroundColor(.orange)
                            Text("Failed to load image")
                                .foregroundColor(.secondary)
                        }
                    @unknown default:
                        EmptyView()
                    }
                }
                .navigationTitle("Original Image")
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
}

// New View for displaying eBay matches in segmented results
struct EbayMatchesView: View {
    let matches: [EbayMatch]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if matches.isEmpty {
                Text("No matches found")
                    .foregroundColor(.secondary)
                    .italic()
                    .padding(.horizontal)
            } else {
                ForEach(matches) { match in
                    Link(destination: match.link) {
                        HStack {
                VStack(alignment: .leading, spacing: 4) {
                                Text(match.phrase)
                        .font(.subheadline)
                                    .foregroundColor(.primary)
                        .lineLimit(2)
                    
                                Text(match.link.absoluteString)
                            .font(.caption)
                            .foregroundColor(.blue)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                }
                
                Spacer()
                
                            Image(systemName: "arrow.up.right.square")
                                .foregroundColor(.blue)
                                .font(.title2)
            }
            .padding()
            .background(Color(.systemGray6))
                        .cornerRadius(8)
        }
        .padding(.horizontal)
                }
            }
        }
    }
} 
 