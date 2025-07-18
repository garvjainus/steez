import SwiftUI
import Kingfisher

struct FrameSelectorView: View {
    let frameUrls: [URL]
    let onFrameSelected: (URL) -> Void
    @State private var selectedFrameIndex: Int? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Select the Clearest Frame")
                    .font(SteezFonts.medium(16))
                    .foregroundColor(SteezColors.textPrimary)
                
                Spacer()
                
                Text("\(frameUrls.count) frames")
                    .font(SteezFonts.regular(12))
                    .foregroundColor(SteezColors.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(SteezColors.textSecondary.opacity(0.1))
                    )
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Array(frameUrls.enumerated()), id: \.offset) { index, url in
                        FrameCard(
                            url: url,
                            index: index,
                            isSelected: selectedFrameIndex == index,
                            onTap: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    selectedFrameIndex = index
                                }
                                
                                // Haptic feedback
                                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                impactFeedback.impactOccurred()
                                
                                onFrameSelected(url)
                            }
                        )
                    }
                }
                .padding(.horizontal, 2) // Small padding for shadows
            }
            
            if selectedFrameIndex != nil {
                Text("Tap to select this frame for analysis")
                    .font(SteezFonts.regular(12))
                    .foregroundColor(SteezColors.textSecondary)
                    .opacity(0.8)
            }
        }
    }
}

struct FrameCard: View {
    let url: URL
    let index: Int
    let isSelected: Bool
    let onTap: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(SteezColors.textSecondary.opacity(0.1))
                        .frame(width: 100, height: 140)
                    
                    KFImage(url)
                        .placeholder {
                            VStack {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: SteezColors.primary))
                                    .scaleEffect(0.8)
                                Text("Loading...")
                                    .font(SteezFonts.regular(10))
                                    .foregroundColor(SteezColors.textSecondary)
                            }
                        }
                        .retry(maxCount: 3)
                        .onFailure { error in
                            print("Failed to load frame: \(error)")
                        }
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 100, height: 140)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    // Selection overlay
                    if isSelected {
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [SteezColors.primary, SteezColors.primaryLight],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 3
                            )
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(SteezColors.primary.opacity(0.1))
                            )
                        
                        // Checkmark
                        VStack {
                            HStack {
                                Spacer()
                                ZStack {
                                    Circle()
                                        .fill(SteezColors.primary)
                                        .frame(width: 24, height: 24)
                                    
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }
                            Spacer()
                        }
                        .padding(8)
                    }
                }
                
                Text("Frame \(index + 1)")
                    .font(SteezFonts.regular(10))
                    .foregroundColor(isSelected ? SteezColors.primary : SteezColors.textSecondary)
            }
            .scaleEffect(isPressed ? 0.95 : (isSelected ? 1.05 : 1.0))
            .shadow(
                color: isSelected ? SteezColors.primary.opacity(0.3) : Color.black.opacity(0.1),
                radius: isSelected ? 8 : 4,
                x: 0,
                y: isSelected ? 4 : 2
            )
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSelected)
    }
}

#if DEBUG
#Preview {
    FrameSelectorView(frameUrls: [
        URL(string: "https://example.com/frame1.jpg")!,
        URL(string: "https://example.com/frame2.jpg")!,
        URL(string: "https://example.com/frame3.jpg")!
    ]) { url in
        print("Selected: \(url)")
    }
    .padding()
}
#endif 