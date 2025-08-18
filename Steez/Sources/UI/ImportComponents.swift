import SwiftUI
import PhotosUI
import Kingfisher

// MARK: - Import Options View
struct ImportOptionsView: View {
    let onCameraAction: () -> Void
    let onPhotoLibraryAction: () -> Void
    let onLinkAction: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            ImportOptionCard(
                icon: "camera.fill",
                title: "Take Photo",
                subtitle: "Capture an outfit or clothing item",
                primaryAction: true,
                action: onCameraAction
            )
            
            ImportOptionCard(
                icon: "photo.on.rectangle",
                title: "Choose from Photos",
                subtitle: "Select from your photo library",
                primaryAction: false,
                action: onPhotoLibraryAction
            )
            
            ImportOptionCard(
                icon: "link",
                title: "Paste Link",
                subtitle: "From TikTok, Instagram, or other social media",
                primaryAction: false,
                action: onLinkAction
            )
        }
    }
}

struct ImportOptionCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let primaryAction: Bool
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(primaryAction ? 
                            LinearGradient(
                                colors: [SteezColors.primary, SteezColors.primaryLight],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ) :
                            LinearGradient(
                                colors: [SteezColors.primary.opacity(0.1), SteezColors.primary.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: icon)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(primaryAction ? .white : SteezColors.primary)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(SteezFonts.medium(18))
                        .foregroundColor(SteezColors.textPrimary)
                    
                    Text(subtitle)
                        .font(SteezFonts.regular(14))
                        .foregroundColor(SteezColors.textSecondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(SteezColors.textSecondary)
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(SteezColors.cardBackground)
                    .shadow(color: .black.opacity(0.05), radius: primaryAction ? 15 : 8, x: 0, y: primaryAction ? 5 : 2)
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

// MARK: - Processing View
struct ProcessingView: View {
    let isUploading: Bool
    let uploadProgress: Float
    
    var body: some View {
        VStack(spacing: 24) {
            // Animated Circle
            ZStack {
                Circle()
                    .stroke(SteezColors.primary.opacity(0.2), lineWidth: 4)
                    .frame(width: 80, height: 80)
                
                if isUploading {
                    Circle()
                        .trim(from: 0, to: CGFloat(uploadProgress))
                        .stroke(
                            LinearGradient(
                                colors: [SteezColors.primary, SteezColors.primaryLight],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .frame(width: 80, height: 80)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut, value: uploadProgress)
                } else {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: SteezColors.primary))
                        .scaleEffect(1.5)
                }
            }
            
            VStack(spacing: 8) {
                Text(isUploading ? "Uploading..." : "Processing...")
                    .font(SteezFonts.medium(18))
                    .foregroundColor(SteezColors.textPrimary)
                
                if isUploading {
                    Text("\(Int(uploadProgress * 100))%")
                        .font(SteezFonts.regular(14))
                        .foregroundColor(SteezColors.textSecondary)
                } else {
                    Text("Analyzing your style...")
                        .font(SteezFonts.regular(14))
                        .foregroundColor(SteezColors.textSecondary)
                }
            }
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(SteezColors.cardBackground)
                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 2)
        )
    }
}

// MARK: - Retry Upload View
struct RetryUploadView: View {
    let image: UIImage
    let onRetry: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            
            VStack(spacing: 12) {
                Text("Upload Failed")
                    .font(SteezFonts.medium(18))
                    .foregroundColor(SteezColors.textPrimary)
                
                Text("Please check your connection and try again")
                    .font(SteezFonts.regular(14))
                    .foregroundColor(SteezColors.textSecondary)
                    .multilineTextAlignment(.center)
                
                Button("Try Again") {
                    onRetry()
                }
                .buttonStyle(PrimaryButtonStyle())
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

// MARK: - Link Input View
struct LinkInputView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    @State private var linkText = ""
    @State private var isProcessing = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    Text("Paste Link")
                        .font(SteezFonts.medium(24))
                        .foregroundColor(SteezColors.textPrimary)
                    
                    Text("Paste a link from TikTok, Instagram, or other social media")
                        .font(SteezFonts.regular(16))
                        .foregroundColor(SteezColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 32)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Video URL")
                        .font(SteezFonts.medium(14))
                        .foregroundColor(SteezColors.textPrimary)
                    
                    TextField("Paste link here...", text: $linkText)
                        .textFieldStyle(ModernTextFieldStyle())
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                }
                
                Spacer()
                
                VStack(spacing: 12) {
                    Button("Process Video") {
                        processVideoLink()
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(linkText.isEmpty || isProcessing)
                    
                    Button("Cancel") {
                        dismiss()
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
                .padding(.bottom, 32)
            }
            .padding(.horizontal, 24)
            .background(SteezColors.background)
        }
    }
    
    private func processVideoLink() {
        guard !linkText.isEmpty else { return }
        
        isProcessing = true
        
        // TODO: Implement video processing logic
        // For now, we'll just simulate processing
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.isProcessing = false
            // Show success or error based on processing result
            dismiss()
        }
    }
}

// MARK: - Status Indicators
struct JobPollingIndicator: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        Group {
            if appState.isPollingForJob {
                VStack(spacing: 12) {
                    HStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: SteezColors.primary))
                            .scaleEffect(0.8)
                        
                        Text("Processing your video...")
                            .font(SteezFonts.medium(16))
                            .foregroundColor(SteezColors.textPrimary)
                    }
                    
                    if let jobId = appState.pollingJobId {
                        Text("Job ID: \(jobId)")
                            .font(SteezFonts.regular(12))
                            .foregroundColor(SteezColors.textSecondary)
                    }
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(SteezColors.primary.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(SteezColors.primary.opacity(0.2), lineWidth: 1)
                        )
                )
            } else if let errorMessage = appState.jobErrorMessage {
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(SteezColors.error)
                        Text("Processing Failed")
                            .font(SteezFonts.medium(16))
                            .foregroundColor(SteezColors.textPrimary)
                    }
                    
                    Text(errorMessage)
                        .font(SteezFonts.regular(14))
                        .foregroundColor(SteezColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(SteezColors.error.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(SteezColors.error.opacity(0.2), lineWidth: 1)
                        )
                )
            }
        }
    }
}

// MARK: - Uploaded Image View
struct UploadedImageView: View {
    let imageUrl: URL
    @State private var isExpanded = false
    
    var body: some View {
        VStack(spacing: 16) {
            Button(action: {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    isExpanded = true
                }
            }) {
                AsyncImage(url: imageUrl) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(height: 200)
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill() // fill, not fit
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                            .clipped() // crop overflow to screen bounds
                            .ignoresSafeArea()
                    case .failure:
                        RoundedRectangle(cornerRadius: 16)
                            .fill(SteezColors.textSecondary.opacity(0.1))
                            .frame(height: 200)
                            .overlay(
                                VStack {
                                    Image(systemName: "photo")
                                        .font(.title)
                                        .foregroundColor(SteezColors.textSecondary)
                                    Text("Failed to load")
                                        .font(SteezFonts.regular(14))
                                        .foregroundColor(SteezColors.textSecondary)
                                }
                            )
                    @unknown default:
                        EmptyView()
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            Text("Image uploaded successfully")
                .font(SteezFonts.regular(14))
                .foregroundColor(SteezColors.success)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(SteezColors.cardBackground)
                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 2)
        )
        .fullScreenCover(isPresented: $isExpanded) {
            FullScreenImageView(imageUrl: imageUrl)
        }
    }
}

// MARK: - Full Screen Image View
struct FullScreenImageView: View {
    @Environment(\.dismiss) private var dismiss
    let imageUrl: URL

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Fill the entire screen
            AsyncImage(url: imageUrl) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill() // fill, not fit
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        .clipped() // crop overflow to screen bounds
                        .ignoresSafeArea()
                case .failure:
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.largeTitle)
                            .foregroundColor(.yellow)
                        Text("Failed to load image")
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.ignoresSafeArea())
                default:
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.6)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.ignoresSafeArea())
                }
            }
            // ❌ Remove .padding() — that was shrinking it

            // Close button
            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundColor(.white.opacity(0.9))
                            .shadow(radius: 4)
                    }
                    .padding(.top, 8)
                    .padding(.trailing, 8)
                }
                Spacer()
            }
            .ignoresSafeArea() // keep it reachable under notches
        }
    }
}
