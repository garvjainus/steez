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
            // Background
            Color(hex: "FCFCFC").ignoresSafeArea()

            VStack(spacing: 20) {
                
                // Header
                VStack {
                    Text("Welcome to Steez")
                        .font(.custom("IBMPlexSans-Medium", size: 32))
                    Text(authType == .signIn ? "Sign in to continue" : "Create an account")
                        .font(.custom("IBMPlexSans-Regular", size: 18))
                        .foregroundColor(.gray)
                }
                .padding(.bottom, 30)

                // Auth type picker
                Picker("Authentication", selection: $authType) {
                    ForEach(AuthType.allCases, id: \.self) {
                        Text($0.rawValue)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                
                // Form Fields
                VStack(spacing: 15) {
                    TextField("Email", text: $email)
                        .padding()
                        .background(Color.white)
                        .cornerRadius(10)
                        .shadow(color: .gray.opacity(0.1), radius: 5, x: 0, y: 2)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)

                    SecureField("Password", text: $password)
                        .padding()
                        .background(Color.white)
                        .cornerRadius(10)
                        .shadow(color: .gray.opacity(0.1), radius: 5, x: 0, y: 2)
                }
                .padding(.horizontal)
                
                // Error message
                if let authError {
                    Text(authError.localizedDescription)
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding(.horizontal)
                }
                
                // Success message
                if showingSuccessMessage {
                    Text(successMessage)
                        .foregroundColor(.green)
                        .font(.caption)
                        .padding(.horizontal)
                        .multilineTextAlignment(.center)
                }

                // Action Button
                Button(action: handleAuthAction) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text(authType.rawValue)
                                .font(.custom("IBMPlexSans-Medium", size: 18))
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        LinearGradient(
                            colors: [
                                Color(red: 0.54, green: 0.17, blue: 0.22),
                                Color(red: 0.64, green: 0.27, blue: 0.32)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(28)
                    .shadow(color: Color(red: 0.54, green: 0.17, blue: 0.22).opacity(0.3), radius: 10, x: 0, y: 5)
                }
                .padding()
                .disabled(isLoading)
                
                Spacer()
            }
            .padding(.top, 60)
        }
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

#if DEBUG
struct AuthView_Previews: PreviewProvider {
    static var previews: some View {
        AuthView()
            .environmentObject(AppState())
    }
}
#endif 