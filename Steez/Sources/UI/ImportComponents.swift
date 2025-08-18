import SwiftUI
import PhotosUI
import Kingfisher

// MARK: - Import Options View
struct ImportOptionsView: View {
    @EnvironmentObject var appState: AppState
    let onCameraAction: () -> Void
    let onPhotoLibraryAction: () -> Void
    let onLinkAction: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            // Usage quota status display
            if let quota = appState.currentUsageQuota {
                UsageStatusCard(quota: quota)
            }
            
            ImportOptionCard(
                icon: "camera.fill",
                title: "Take Photo",
                subtitle: "Capture an outfit or clothing item",
                primaryAction: true,
                disabled: !canPerformUpload,
                action: {
                    Task {
                        if await appState.canPerformAction(.upload) {
                            onCameraAction()
                        }
                        // If quota exceeded, paywall is automatically shown by canPerformAction
                    }
                }
            )
            
            ImportOptionCard(
                icon: "photo.on.rectangle",
                title: "Choose from Photos",
                subtitle: "Select from your photo library",
                primaryAction: false,
                disabled: !canPerformUpload,
                action: {
                    Task {
                        if await appState.canPerformAction(.upload) {
                            onPhotoLibraryAction()
                        }
                        // If quota exceeded, paywall is automatically shown by canPerformAction
                    }
                }
            )
            
            ImportOptionCard(
                icon: "link",
                title: "Paste Link",
                subtitle: "From TikTok, Instagram, or other social media",
                primaryAction: false,
                disabled: !canPerformUpload,
                action: {
                    Task {
                        if await appState.canPerformAction(.upload) {
                            onLinkAction()
                        }
                        // If quota exceeded, paywall is automatically shown by canPerformAction
                    }
                }
            )
            
            // Upgrade to Pro button
            UpgradeToProButton()
        }
    }
    
    private var canPerformUpload: Bool {
        guard let quota = appState.currentUsageQuota else { return true }
        return quota.canUpload
    }
}

struct ImportOptionCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let primaryAction: Bool
    let disabled: Bool
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: disabled ? {} : action) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(buttonGradient)
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: disabled ? "lock.fill" : icon)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(iconColor)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(disabled ? "Quota Used" : title)
                        .font(SteezFonts.medium(18))
                        .foregroundColor(textColor)
                    
                    Text(disabled ? "Upgrade to Steez Pro for unlimited uploads" : subtitle)
                        .font(SteezFonts.regular(14))
                        .foregroundColor(subtitleColor)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                Image(systemName: disabled ? "crown.fill" : "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(disabled ? SteezColors.accent : SteezColors.textSecondary)
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(SteezColors.surface)
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
    
    private var buttonGradient: LinearGradient {
        if primaryAction {
            return LinearGradient(
                colors: [SteezColors.primary, SteezColors.primaryLight],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                colors: [SteezColors.primary.opacity(0.1), SteezColors.primary.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    private var iconColor: Color {
        if disabled {
            return SteezColors.accent
        } else if primaryAction {
            return .white
        } else {
            return SteezColors.primary
        }
    }
    
    private var textColor: Color {
        SteezColors.textPrimary
    }
    
    private var subtitleColor: Color {
        disabled ? SteezColors.accent : SteezColors.textSecondary
    }
}

// MARK: - Upgrade to Pro Button
struct UpgradeToProButton: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        Button(action: {
            Task {
                await appState.showPaywall(for: .general)
            }
        }) {
            HStack(spacing: 16) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(SteezColors.accent)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Upgrade to Steez Pro")
                        .font(SteezFonts.medium(18))
                        .foregroundColor(SteezColors.textPrimary)
                    
                    Text("Unlock unlimited uploads and premium features")
                        .font(SteezFonts.regular(14))
                        .foregroundColor(SteezColors.textSecondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(SteezColors.textSecondary)
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [
                                SteezColors.accent.opacity(0.1),
                                SteezColors.primary.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                LinearGradient(
                                    colors: [SteezColors.accent.opacity(0.3), SteezColors.primary.opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Upgrade Benefit Row
struct UpgradeBenefitRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(SteezColors.accent)
                .frame(width: 20)
            
            Text(text)
                .font(SteezFonts.regular(15))
                .foregroundColor(SteezColors.textSecondary)
            
            Spacer()
        }
    }
}

// MARK: - Usage Status Card
struct UsageStatusCard: View {
    @EnvironmentObject var appState: AppState
    let quota: UsageQuota
    
    var body: some View {
        Button(action: {
            Task {
                await appState.showPaywall(for: .upload)
            }
        }) {
        HStack(spacing: 12) {
            // Status icon
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.2))
                    .frame(width: 40, height: 40)
                
                Image(systemName: statusIcon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(statusColor)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(statusTitle)
                    .font(SteezFonts.medium(16))
                    .foregroundColor(SteezColors.textPrimary)
                
                Text(statusSubtitle)
                    .font(SteezFonts.regular(13))
                    .foregroundColor(SteezColors.textSecondary)
            }
            
            Spacer()
            
            if quota.isPro {
                HStack(spacing: 4) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 12))
                        .foregroundColor(SteezColors.accent)
                    
                    Text("PRO")
                        .font(SteezFonts.regular(12))
                        .foregroundColor(SteezColors.accent)
                }
            } else {
                Text("\(quota.totalCount)/1")
                    .font(SteezFonts.regular(14))
                    .foregroundColor(statusColor)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(SteezColors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(statusColor.opacity(0.2), lineWidth: 1)
                )
        )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var statusIcon: String {
        if quota.isPro {
            return "crown.fill"
        } else if quota.canUpload {
            return "checkmark.circle.fill"
        } else {
            return "exclamationmark.triangle.fill"
        }
    }
    
    private var statusColor: Color {
        if quota.isPro {
            return SteezColors.accent
        } else if quota.canUpload {
            return .green
        } else {
            return .orange
        }
    }
    
    private var statusTitle: String {
        if quota.isPro {
            return "Steez Pro Active"
        } else if quota.canUpload {
            return "Daily Upload Available"
        } else {
            return "Daily Limit Reached"
        }
    }
    
    private var statusSubtitle: String {
        if quota.isPro {
            return "Unlimited uploads and shares"
        } else if quota.canUpload {
            return "You have \(1 - quota.totalCount) upload remaining today"
        } else {
            return "Upgrade to Pro for unlimited uploads"
        }
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
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .frame(width: 80, height: 80)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.5), value: uploadProgress)
                } else {
                    Circle()
                        .stroke(SteezColors.primary, lineWidth: 4)
                        .frame(width: 80, height: 80)
                        .scaleEffect(1.2)
                        .opacity(0.8)
                        .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isUploading)
                }
                
                Image(systemName: isUploading ? "arrow.up.doc" : "sparkles")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(SteezColors.primary)
            }
            
            // Status Text
            VStack(spacing: 8) {
                Text(isUploading ? "Uploading..." : "Processing")
                    .font(SteezFonts.regular(20))
                    .foregroundColor(SteezColors.textPrimary)
                
                Text(isUploading ? 
                    "Upload progress: \(Int(uploadProgress * 100))%" : 
                    "Analyzing your image with AI"
                )
                    .font(SteezFonts.regular(16))
                    .foregroundColor(SteezColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(40)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(SteezColors.surface)
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
                .aspectRatio(contentMode: .fit)
                .frame(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            
            VStack(spacing: 12) {
                Text("Upload Failed")
                    .font(SteezFonts.regular(20))
                    .foregroundColor(SteezColors.textPrimary)
                
                Text("There was an issue uploading your image. Please try again.")
                    .font(SteezFonts.regular(16))
                    .foregroundColor(SteezColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            Button(action: onRetry) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                    Text("Retry Upload")
                        .font(SteezFonts.regular(16))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(SteezColors.primary)
                )
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(SteezColors.surface)
        )
    }
}

// MARK: - Uploaded Image View
struct UploadedImageView: View {
    let imageUrl: URL
    
    var body: some View {
        VStack(spacing: 16) {
            KFImage(imageUrl)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(SteezColors.primary.opacity(0.2), lineWidth: 1)
                )
            
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                
                Text("Analysis Complete")
                    .font(SteezFonts.medium(16))
                    .foregroundColor(SteezColors.textPrimary)
            }
        }
    }
}
