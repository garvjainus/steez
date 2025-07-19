import SwiftUI

// MARK: - Discover View (Main Hub)
struct DiscoverView: View {
    @EnvironmentObject var appState: AppState
    @Binding var selectedTab: Int // Add binding for tab selection
    
    @State private var animateHeader = false
    @State private var animateCards = false
    @State private var showingPreferences = false
    
    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 32) {
                    // Header
                    VStack(spacing: 8) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Discover")
                                    .font(SteezFonts.medium(32))
                                    .foregroundColor(SteezColors.textPrimary)
                                
                                Text("Find your style inspiration")
                                    .font(SteezFonts.regular(16))
                                    .foregroundColor(SteezColors.textSecondary)
                            }
                            
                            Spacer()
                            
                            Button(action: { showingPreferences = true }) {
                                Image(systemName: "gearshape.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(SteezColors.textSecondary)
                            }
                        }
                        .opacity(animateHeader ? 1 : 0)
                        .offset(y: animateHeader ? 0 : -20)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    
                    // Quick Actions
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        QuickActionCard(
                            icon: "camera.fill",
                            title: "Scan Outfit",
                            subtitle: "Take a photo",
                            color: SteezColors.primary,
                            action: {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    selectedTab = 1 // Switch to the second tab (Import)
                                }
                            }
                        )
                        
                        QuickActionCard(
                            icon: "link",
                            title: "From Link",
                            subtitle: "TikTok, Instagram",
                            color: SteezColors.primaryLight,
                            action: {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    selectedTab = 1 // Switch to the second tab (Import)
                                }
                            }
                        )
                    }
                    .padding(.horizontal, 24)
                    .opacity(animateCards ? 1 : 0)
                    .offset(y: animateCards ? 0 : 30)
                    
                    // Recent Activity (if any)
                    if !appState.jobFrames.isEmpty || appState.segmentedResults != nil {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("Recent Activity")
                                    .font(SteezFonts.medium(20))
                                    .foregroundColor(SteezColors.textPrimary)
                                
                                Spacer()
                                
                                Button("Clear") {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        appState.clearResults()
                                    }
                                }
                                .font(SteezFonts.regular(14))
                                .foregroundColor(SteezColors.primary)
                            }
                            .padding(.horizontal, 24)
                            
                            // Show recent results
                            if !appState.jobFrames.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Video Frames")
                                        .font(SteezFonts.medium(16))
                                        .foregroundColor(SteezColors.textPrimary)
                                        .padding(.horizontal, 24)
                                    
                                    FrameSelectorView(frameUrls: appState.jobFrames) { selectedUrl in
                                        // Handle frame selection - could navigate to import tab
                                    }
                                }
                            }
                            
                            if let segmentedResults = appState.segmentedResults {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Detected Items (\(segmentedResults.totalItems))")
                                        .font(SteezFonts.medium(16))
                                        .foregroundColor(SteezColors.textPrimary)
                                        .padding(.horizontal, 24)
                                    
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 12) {
                                            ForEach(Array(segmentedResults.segments.enumerated()), id: \.offset) { index, segment in
                                                SegmentPreviewCard(segment: segment)
                                            }
                                        }
                                        .padding(.horizontal, 24)
                                    }
                                }
                            }
                        }
                    }
                    
                    Spacer(minLength: 100) // Space for tab bar
                }
            }
            .refreshable {
                // Refresh action - could reload recent activity
            }
        }
        .sheet(isPresented: $showingPreferences) {
            UserPreferencesView()
                .environmentObject(appState)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                animateHeader = true
            }
            
            withAnimation(.easeOut(duration: 0.8).delay(0.2)) {
                animateCards = true
            }
        }
    }
}

// MARK: - Segment Preview Card
struct SegmentPreviewCard: View {
    let segment: ClothingSegment
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(segment.itemType.capitalized)
                .font(SteezFonts.medium(14))
                .foregroundColor(SteezColors.textPrimary)
            
            Text(String(format: "%.0f%% confident", segment.confidence * 100))
                .font(SteezFonts.regular(12))
                .foregroundColor(SteezColors.textSecondary)
            
            Text("\(segment.ebayResults.count) matches")
                .font(SteezFonts.regular(10))
                .foregroundColor(SteezColors.primary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(SteezColors.cardBackground)
                .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        )
        .frame(width: 120)
    }
}

#Preview {
    DiscoverView(selectedTab: .constant(0))
        .environmentObject(AppState())
} 