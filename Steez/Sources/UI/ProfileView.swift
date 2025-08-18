import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var appState: AppState
    @State private var animateContent = false
    @State private var showingDeleteSheet = false
    @State private var deleteConfirmationInput = ""
    
    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 32) {
                    // Header
                    VStack(spacing: 16) {
                        // Profile Avatar
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [SteezColors.primary, SteezColors.primaryLight],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 80, height: 80)
                            
                            Text(appState.currentUser?.email.prefix(1).uppercased() ?? "U")
                                .font(SteezFonts.medium(32))
                                .foregroundColor(.white)
                        }
                        .scaleEffect(animateContent ? 1.0 : 0.8)
                        .opacity(animateContent ? 1.0 : 0.0)
                        
                        VStack(spacing: 4) {
                            Text(appState.currentUser?.email ?? "Guest User")
                                .font(SteezFonts.medium(20))
                                .foregroundColor(SteezColors.textPrimary)
                            
                            Text("Free Plan")
                                .font(SteezFonts.regular(14))
                                .foregroundColor(SteezColors.textSecondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(SteezColors.primary.opacity(0.1))
                                )
                        }
                        .opacity(animateContent ? 1.0 : 0.0)
                        .offset(y: animateContent ? 0 : 20)
                    }
                    .padding(.top, 16)
                    
                    // Settings Sections
                    VStack(spacing: 24) {
                        ProfileSection(title: "Preferences") {
                            ProfileSettingRow(
                                icon: "person.crop.circle",
                                title: "Size",
                                value: appState.userSize,
                                action: { /* Edit size */ }
                            )
                            
                            ProfileSettingRow(
                                icon: "location",
                                title: "Country",
                                value: appState.userCountry,
                                action: { /* Edit country */ }
                            )
                        }
                        
                        ProfileSection(title: "Support") {
                            ProfileActionRow(
                                icon: "questionmark.circle",
                                title: "Help Center",
                                action: { /* Open help */ }
                            )
                            
                            ProfileActionRow(
                                icon: "envelope",
                                title: "Contact Us",
                                action: { /* Open contact */ }
                            )
                            
                            ProfileActionRow(
                                icon: "star",
                                title: "Rate App",
                                action: { /* Rate app */ }
                            )
                        }
                        
                        ProfileSection(title: "Legal") {
                            NavigationLink(destination: PrivacyPolicyView()) {
                                ProfileActionRow(icon: "lock.shield", title: "Privacy Policy")
                            }
                            
                            NavigationLink(destination: TermsOfServiceView()) {
                                ProfileActionRow(icon: "doc.text", title: "Terms of Service")
                            }
                        }

                        ProfileSection(title: "Account") {
                            ProfileActionRow(
                                icon: "trash",
                                title: "Delete Account",
                                destructive: true,
                                action: {
                                    deleteConfirmationInput = ""
                                    showingDeleteSheet = true
                                }
                            )
                        }

                        // Always show the debug section
                        ProfileSection(title: "Debug") {
                            ProfileActionRow(
                                icon: "arrow.clockwise",
                                title: "Reset Onboarding",
                                destructive: true,
                                action: {
                                    appState.resetOnboarding()
                                }
                            )
                            
                            ProfileActionRow(
                                icon: "trash",
                                title: "Clear Results",
                                destructive: true,
                                action: {
                                    appState.clearResults()
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 24)
                    .opacity(animateContent ? 1.0 : 0.0)
                    .offset(y: animateContent ? 0 : 30)
                    
                    Spacer(minLength: 100)
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showingDeleteSheet) {
                DeleteAccountConfirmationView(isPresented: $showingDeleteSheet, userEmail: appState.currentUser?.email ?? "", input: $deleteConfirmationInput) {
                    Task {
                        do {
                            try await SupabaseService.shared.deleteUser()
                        } catch {
                            print("Error deleting user: \(error)")
                        }
                    }
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                animateContent = true
            }
        }
    }
}

// MARK: - Profile Components
struct ProfileSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(SteezFonts.medium(18))
                .foregroundColor(SteezColors.textPrimary)
            
            VStack(spacing: 0) {
                content
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(SteezColors.cardBackground)
                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
            )
        }
    }
}

struct ProfileSettingRow: View {
    let icon: String
    let title: String
    let value: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(SteezColors.primary)
                    .frame(width: 24)
                
                Text(title)
                    .font(SteezFonts.medium(16))
                    .foregroundColor(SteezColors.textPrimary)
                
                Spacer()
                
                Text(value)
                    .font(SteezFonts.regular(14))
                    .foregroundColor(SteezColors.textSecondary)
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(SteezColors.textSecondary)
            }
            .padding(16)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ProfileToggleRow: View {
    let icon: String
    let title: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(SteezColors.primary)
                .frame(width: 24)
            
            Text(title)
                .font(SteezFonts.medium(16))
                .foregroundColor(SteezColors.textPrimary)
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .toggleStyle(SwitchToggleStyle(tint: SteezColors.primary))
        }
        .padding(16)
    }
}

struct ProfileActionRow: View {
    let icon: String
    let title: String
    let destructive: Bool
    let showChevron: Bool
    let action: (() -> Void)?
    let isNavigationRow: Bool
    
    init(
        icon: String, 
        title: String, 
        destructive: Bool = false, 
        showChevron: Bool = true, 
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.destructive = destructive
        self.showChevron = showChevron
        self.action = action
        self.isNavigationRow = action == nil
    }
    
    var body: some View {
        let content = HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(destructive ? SteezColors.error : SteezColors.primary)
                .frame(width: 24)
            
            Text(title)
                .font(SteezFonts.medium(16))
                .foregroundColor(destructive ? SteezColors.error : SteezColors.textPrimary)
            
            Spacer()
            
            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(SteezColors.textSecondary)
            }
        }
        .padding(16)
        
        if let action = action {
            Button(action: action) {
                content
            }
            .buttonStyle(PlainButtonStyle())
        } else {
            content
        }
    }
}

#Preview {
    ProfileView()
        .environmentObject(AppState())
} 