import SwiftUI
import Supabase

struct AuthView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var authType: AuthType = .signIn
    @State private var isLoading = false
    @State private var authError: Error?
    @State private var showingSuccessMessage = false
    @State private var successMessage = ""
    
    @EnvironmentObject var appState: AppState
    
    enum AuthType: String, CaseIterable {
        case signIn = "Sign In"
        case signUp = "Sign Up"
    }

    var body: some View {
        ZStack {
            SteezColors.background
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 32) {
                    // Header
                    VStack(spacing: 16) {
                        Text("Welcome to Steez")
                            .font(SteezFonts.medium(32))
                            .foregroundColor(SteezColors.textPrimary)
                        
                        Text(authType == .signIn ? "Sign in to continue" : "Create an account")
                            .font(SteezFonts.regular(16))
                            .foregroundColor(SteezColors.textSecondary)
                    }
                    .padding(.top, 48)
                    
                    // Auth Type Picker
                    Picker("Authentication", selection: $authType) {
                        ForEach(AuthType.allCases, id: \.self) {
                            Text($0.rawValue)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal, 24)
                    
                    // Form Fields
                    VStack(spacing: 20) {
                        TextField("Email", text: $email)
                            .textFieldStyle(ModernTextFieldStyle())
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                        
                        SecureField("Password", text: $password)
                            .textFieldStyle(ModernTextFieldStyle())
                    }
                    .padding(.horizontal, 24)
                    
                    // Messages
                    if let authError {
                        ErrorMessageView(message: authError.localizedDescription)
                    }
                    
                    if showingSuccessMessage {
                        SuccessMessageView(message: successMessage)
                    }
                    
                    // Action Button
                    Button(action: handleAuthAction) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text(authType.rawValue)
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.horizontal, 24)
                    .disabled(isLoading)
                }
            }
        }
        .animation(.easeInOut, value: authType)
    }
    
    private func handleAuthAction() {
        isLoading = true
        authError = nil
        showingSuccessMessage = false
        
        Task {
            do {
                switch authType {
                case .signIn:
                    try await SupabaseService.shared.signIn(email: email, password: password)
                    await MainActor.run {
                        successMessage = "Successfully signed in!"
                        showingSuccessMessage = true
                    }
                case .signUp:
                    try await SupabaseService.shared.signUp(email: email, password: password)
                    await MainActor.run {
                        successMessage = "Account created! Please check your email to confirm your account."
                        showingSuccessMessage = true
                    }
                }
            } catch {
                await MainActor.run {
                    self.authError = error
                }
            }
            // Ensure loading state is reset on the main thread
            await MainActor.run {
                isLoading = false
            }
        }
    }
}

// MARK: - Message Views
struct ErrorMessageView: View {
    let message: String
    
    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(SteezColors.error)
            Text(message)
                .font(SteezFonts.regular(14))
                .foregroundColor(SteezColors.textPrimary)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(SteezColors.error.opacity(0.1))
        )
        .padding(.horizontal, 24)
    }
}

struct SuccessMessageView: View {
    let message: String
    
    var body: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(SteezColors.success)
            Text(message)
                .font(SteezFonts.regular(14))
                .foregroundColor(SteezColors.textPrimary)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(SteezColors.success.opacity(0.1))
        )
        .padding(.horizontal, 24)
    }
}

#if DEBUG
struct AuthView_Previews: PreviewProvider {
    static var previews: some View {
        AuthView()
            .environmentObject(AppState())
    }
}
#endif 