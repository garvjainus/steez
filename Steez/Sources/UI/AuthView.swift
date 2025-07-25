import SwiftUI
import Supabase
import AuthenticationServices
import CryptoKit
import GoogleSignIn

struct AuthView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var authType: AuthType = .signIn
    @State private var isLoading = false
    @State private var authError: Error?
    @State private var showingSuccessMessage = false
    @State private var successMessage = ""
    @State private var isEmailFocused = false
    @State private var isPasswordFocused = false
    @State private var showPassword = false
    @State private var showingForgotPasswordAlert = false
    @State private var forgotPasswordEmail = ""
    @State private var currentNonce: String?
    
    @EnvironmentObject var appState: AppState
    
    enum AuthType: String, CaseIterable {
        case signIn = "Sign In"
        case signUp = "Sign Up"
        
        var title: String {
            switch self {
            case .signIn: return "Welcome Back"
            case .signUp: return "Create Account"
            }
        }
        
        var subtitle: String {
            switch self {
            case .signIn: return "Sign in to discover your style"
            case .signUp: return "Join the fashion community"
            }
        }
        
        var buttonText: String {
            switch self {
            case .signIn: return "Sign In"
            case .signUp: return "Create Account"
            }
        }
    }
    
    private var isFormValid: Bool {
        !email.isEmpty && !password.isEmpty && email.contains("@")
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [
                        SteezColors.primary.opacity(0.1),
                        SteezColors.accent.opacity(0.05),
                        SteezColors.background
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 0) {
                        // Header Section
                        VStack(spacing: 24) {
                            // Logo/Brand
                            VStack(spacing: 16) {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [SteezColors.primary, SteezColors.accent],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 80, height: 80)
                                    .overlay(
                                        Text("S")
                                            .font(SteezFonts.medium(36))
                                            .foregroundColor(.white)
                                    )
                                    .shadow(color: SteezColors.primary.opacity(0.3), radius: 20, x: 0, y: 10)
                                
                                VStack(spacing: 8) {
                                    Text(authType.title)
                                        .font(SteezFonts.medium(32))
                                        .foregroundColor(SteezColors.textPrimary)
                                    
                                    Text(authType.subtitle)
                                        .font(SteezFonts.regular(16))
                                        .foregroundColor(SteezColors.textSecondary)
                                        .multilineTextAlignment(.center)
                                }
                            }
                            .padding(.top, 60)
                        }
                        
                        // Auth Type Switcher
                        Picker("", selection: $authType) {
                            ForEach(AuthType.allCases, id: \.self) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal, 32)
                        .padding(.top, 40)
                        
                        // Form Section
                        VStack(spacing: 24) {
                            // Email Field
                            FloatingLabelTextField(
                                text: $email,
                                label: "Email Address",
                                isFocused: $isEmailFocused,
                                keyboardType: .emailAddress,
                                systemImage: "envelope"
                            )
                            
                            // Password Field
                            FloatingLabelSecureField(
                                text: $password,
                                label: "Password",
                                isFocused: $isPasswordFocused,
                                showPassword: $showPassword,
                                systemImage: "lock"
                            )
                            
                            if authType == .signIn {
                                forgotPasswordButton
                            }
                        }
                        .padding(.horizontal, 32)
                        .padding(.top, 40)
                        
                        // Messages
                        if let authError {
                            ModernErrorMessage(message: authError.localizedDescription)
                                .padding(.horizontal, 32)
                                .padding(.top, 16)
                                .transition(.asymmetric(
                                    insertion: .scale.combined(with: .opacity),
                                    removal: .opacity
                                ))
                        }
                        
                        if showingSuccessMessage {
                            ModernSuccessMessage(message: successMessage)
                                .padding(.horizontal, 32)
                                .padding(.top, 16)
                                .transition(.asymmetric(
                                    insertion: .scale.combined(with: .opacity),
                                    removal: .opacity
                                ))
                        }
                        
                        // Action Button
                        Button(action: handleAuthAction) {
                            HStack(spacing: 12) {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: authType == .signIn ? "arrow.right.circle" : "person.badge.plus")
                                        .font(.system(size: 18, weight: .medium))
                                    
                                    Text(authType.buttonText)
                                        .font(SteezFonts.medium(18))
                                }
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                Group {
                                    if isFormValid {
                                        LinearGradient(
                                            colors: [SteezColors.primary, SteezColors.accent],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    } else {
                                        Color.gray.opacity(0.3)
                                    }
                                }
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 28))
                            .shadow(
                                color: isFormValid ? SteezColors.primary.opacity(0.4) : Color.clear,
                                radius: 15,
                                x: 0,
                                y: 8
                            )
                            .scaleEffect(isLoading ? 0.95 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isLoading)
                        }
                        .disabled(!isFormValid || isLoading)
                        .padding(.horizontal, 32)
                        .padding(.top, 32)
                        
                        // Social Logins
                        VStack(spacing: 16) {
                            HStack {
                                VStack { Divider().background(SteezColors.textSecondary) }
                                Text("OR")
                                    .font(SteezFonts.regular(14))
                                    .foregroundColor(SteezColors.textSecondary)
                                VStack { Divider().background(SteezColors.textSecondary) }
                            }
                            
                            SignInWithAppleButton(
                                .signIn,
                                onRequest: { request in
                                    let nonce = randomNonceString()
                                    DispatchQueue.main.async {
                                        currentNonce = nonce
                                    }
                                    request.requestedScopes = [.fullName, .email]
                                    request.nonce = sha256(nonce)
                                },
                                onCompletion: handleAppleSignInResult
                            )
                            .signInWithAppleButtonStyle(.black)
                            .frame(height: 56)
                            .clipShape(RoundedRectangle(cornerRadius: 28))
                            
                            googleSignInButton
                        }
                        .padding(.horizontal, 32)
                        .padding(.top, 24)
                        
                        Spacer(minLength: 40)
                    }
                }
                .modifier(ScrollIndicatorModifier())
            }
        }
        .sheet(isPresented: $showingForgotPasswordAlert) {
            ForgotPasswordView(
                isPresented: $showingForgotPasswordAlert,
                email: $forgotPasswordEmail
            )
        }
    }
    
    // MARK: - Subviews
    private var forgotPasswordButton: some View {
        Button(action: {
            forgotPasswordEmail = email // Pre-fill with current email
            showingForgotPasswordAlert = true
        }) {
            Text("Forgot Password?")
                .font(SteezFonts.regular(14))
                .foregroundColor(SteezColors.primary)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.top, 8)
    }
    
    private var googleSignInButton: some View {
        Button(action: {
            // Haptic feedback for tap
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
            handleGoogleSignIn()
        }) {
            HStack(spacing: 12) {
                // Using a globe as a placeholder for the Google logo, styled to fit the theme
                Image(systemName: "globe")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(Color.black.opacity(0.8))

                Text("Continue with Google")
                    .font(SteezFonts.medium(17))
                    .foregroundColor(Color.black.opacity(0.8))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 28))
            .overlay(
                RoundedRectangle(cornerRadius: 28)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        }
    }
    
    // MARK: - Auth Handlers
    private func handleAuthAction() {
        // Haptic feedback
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
        
        isLoading = true
        authError = nil
        showingSuccessMessage = false
        
        Task {
            do {
                switch authType {
                case .signIn:
                    try await SupabaseService.shared.signIn(email: email, password: password)
                    await MainActor.run {
                        successMessage = "Welcome back! 🎉"
                        showingSuccessMessage = true
                        // Success haptic
                        let notification = UINotificationFeedbackGenerator()
                        notification.notificationOccurred(.success)
                    }
                case .signUp:
                    try await SupabaseService.shared.signUp(email: email, password: password)
                    await MainActor.run {
                        successMessage = "Account created! Check your email to get started. 📧"
                        showingSuccessMessage = true
                        // Success haptic
                        let notification = UINotificationFeedbackGenerator()
                        notification.notificationOccurred(.success)
                    }
                }
            } catch {
                await MainActor.run {
                    self.authError = error
                    // Error haptic
                    let notification = UINotificationFeedbackGenerator()
                    notification.notificationOccurred(.error)
                }
            }
            
            await MainActor.run {
                isLoading = false
            }
        }
    }
    
    private func handleAppleSignInResult(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            // Haptic feedback for success
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
            
            guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let idTokenData = appleIDCredential.identityToken,
                  let idToken = String(data: idTokenData, encoding: .utf8),
                  let nonce = currentNonce else {
                self.authError = NSError(domain: "AuthError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not retrieve Apple ID token or nonce."])
                return
            }
            
            Task {
                do {
                    try await SupabaseService.shared.signInWithApple(idToken: idToken, nonce: nonce)
                    await MainActor.run {
                        successMessage = "Successfully signed in with Apple!"
                        showingSuccessMessage = true
                    }
                } catch {
                    await MainActor.run {
                        self.authError = error
                    }
                }
            }
            
        case .failure(let error):
            self.authError = error
        }
    }
    
    private func handleGoogleSignIn() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            self.authError = NSError(domain: "AuthError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not find root view controller for Google Sign-In."])
            return
        }
        
        // The Web Client ID for your Supabase backend, which you provided.
        let serverClientID = "457887251387-alkcktuepl7fsmuid8tdfgpsol96qqnb.apps.googleusercontent.com"
        
        // Set the serverClientID on the shared instance to get a token valid for your backend
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: GIDSignIn.sharedInstance.configuration!.clientID, serverClientID: serverClientID)
        
        Task {
            do {
                // Use the original sign-in method. The configuration is now handled automatically.
                let gidSignInResult = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
                
                // Haptic feedback for success
                let notification = UINotificationFeedbackGenerator()
                notification.notificationOccurred(.success)
                
                guard let idToken = gidSignInResult.user.idToken?.tokenString else {
                    self.authError = NSError(domain: "AuthError", code: 3, userInfo: [NSLocalizedDescriptionKey: "Could not retrieve Google ID token."])
                    return
                }
                
                try await SupabaseService.shared.signInWithGoogle(idToken: idToken)
                
                await MainActor.run {
                    successMessage = "Successfully signed in with Google!"
                    showingSuccessMessage = true
                }
            } catch {
                await MainActor.run {
                    // Don't show an error if the user cancelled the sign-in flow.
                    if (error as NSError).code != GIDSignInError.canceled.rawValue {
                        self.authError = error
                    }
                }
            }
        }
    }
    
    // This function is unused, the one inside ForgotPasswordView is used instead.
    // private func handleForgotPassword(email: String) {
    //     Task {
    //         do {
    //             try await SupabaseService.shared.sendPasswordReset(for: email)
    //             await MainActor.run {
    //                 successMessage = "Password reset link sent to \(email). Please check your inbox."
    //                 showingSuccessMessage = true
    //             }
    //         } catch {
    //             await MainActor.run {
    //                 self.authError = error
    //             }
    //         }
    //     }
    // }
}

// MARK: - Crypto Helpers for Apple Sign-In

private func sha256(_ input: String) -> String {
    let inputData = Data(input.utf8)
    let hashedData = SHA256.hash(data: inputData)
    let hashString = hashedData.compactMap {
        return String(format: "%02x", $0)
    }.joined()
    
    return hashString
}

private func randomNonceString(length: Int = 32) -> String {
    precondition(length > 0)
    let charset: [Character] =
        Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
    var result = ""
    var remainingLength = length
    
    while remainingLength > 0 {
        let randoms: [UInt8] = (0 ..< 16).map { _ in
            var random: UInt8 = 0
            let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
            if errorCode != errSecSuccess {
                fatalError("Unable to generate random bytes. SecRandomCopyBytes failed with OSStatus \(errorCode)")
            }
            return random
        }
        
        for random in randoms {
            if remainingLength == 0 {
                break
            }
            
            if random < charset.count {
                result.append(charset[Int(random)])
                remainingLength -= 1
            }
        }
    }
    
    return result
}

// MARK: - Forgot Password View
struct ForgotPasswordView: View {
    @Binding var isPresented: Bool
    @Binding var email: String
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Reset Password")
                    .font(SteezFonts.medium(24))
                
                Text("Enter your email address and we'll send you a link to reset your password.")
                    .font(SteezFonts.regular(16))
                    .foregroundColor(SteezColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                TextField("Email", text: $email)
                    .textFieldStyle(ModernTextFieldStyle())
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                
                Button(action: {
                    handleForgotPassword()
                    isPresented = false
                }) {
                    Text("Send Reset Link")
                }
                .buttonStyle(PrimaryButtonStyle())
                
                Spacer()
            }
            .padding(32)
            .navigationBarItems(trailing: Button("Cancel") {
                isPresented = false
            })
        }
    }
    
    private func handleForgotPassword() {
        Task {
            do {
                try await SupabaseService.shared.sendPasswordReset(for: email)
                // Optionally show a success message to the user
            } catch {
                // Optionally show an error message to the user
            }
        }
    }
}

// MARK: - Modern Text Field Components

struct FloatingLabelTextField: View {
    @Binding var text: String
    let label: String
    @Binding var isFocused: Bool
    let keyboardType: UIKeyboardType
    let systemImage: String
    
    var body: some View {
        ZStack(alignment: .leading) {
            // Background and Border
            RoundedRectangle(cornerRadius: 16)
                .fill(SteezColors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            isFocused ? SteezColors.primary : Color.clear,
                            lineWidth: 2
                        )
                )
                .shadow(
                    color: isFocused ? SteezColors.primary.opacity(0.2) : Color.black.opacity(0.05),
                    radius: isFocused ? 8 : 4,
                    x: 0,
                    y: isFocused ? 4 : 2
                )

            // Content
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .foregroundColor(isFocused ? SteezColors.primary : SteezColors.textSecondary)
                    .font(.system(size: 18, weight: .medium))
                    .frame(width: 20)

                // The actual text field and its animated label
                ZStack(alignment: .leading) {
                    // The label floats up when text is present or field is focused
                    Text(label)
                        .font(SteezFonts.regular((isFocused || !text.isEmpty) ? 12 : 16))
                        .foregroundColor(isFocused ? SteezColors.primary : SteezColors.textSecondary)
                        .padding(.bottom, (isFocused || !text.isEmpty) ? 28 : 0)
                    
                    TextField("", text: $text, onEditingChanged: { focused in
                        isFocused = focused
                    })
                    .font(SteezFonts.regular(16))
                    .foregroundColor(SteezColors.textPrimary)
                    .keyboardType(keyboardType)
                    .autocapitalization(.none)
                    // Push the text input area down slightly to not overlap with the resting label
                    .padding(.top, (isFocused || !text.isEmpty) ? 12 : 0)
                }
            }
            .padding(.horizontal, 16)
        }
        .frame(height: 56)
        .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isFocused)
        .animation(.spring(response: 0.2, dampingFraction: 0.8), value: !text.isEmpty)
    }
}

struct FloatingLabelSecureField: View {
    @Binding var text: String
    let label: String
    @Binding var isFocused: Bool
    @Binding var showPassword: Bool
    let systemImage: String
    
    var body: some View {
        ZStack(alignment: .leading) {
            // Background and Border
            RoundedRectangle(cornerRadius: 16)
                .fill(SteezColors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            isFocused ? SteezColors.primary : Color.clear,
                            lineWidth: 2
                        )
                )
                .shadow(
                    color: isFocused ? SteezColors.primary.opacity(0.2) : Color.black.opacity(0.05),
                    radius: isFocused ? 8 : 4,
                    x: 0,
                    y: isFocused ? 4 : 2
                )
            
            // Content
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .foregroundColor(isFocused ? SteezColors.primary : SteezColors.textSecondary)
                    .font(.system(size: 18, weight: .medium))
                    .frame(width: 20)

                // The secure field and its animated label
                ZStack(alignment: .leading) {
                    Text(label)
                        .font(SteezFonts.regular((isFocused || !text.isEmpty) ? 12 : 16))
                        .foregroundColor(isFocused ? SteezColors.primary : SteezColors.textSecondary)
                        .padding(.bottom, (isFocused || !text.isEmpty) ? 28 : 0)

                    if showPassword {
                        TextField("", text: $text, onEditingChanged: { focused in
                            isFocused = focused
                        })
                        .font(SteezFonts.regular(16))
                        .foregroundColor(SteezColors.textPrimary)
                        .padding(.top, (isFocused || !text.isEmpty) ? 12 : 0)
                    } else {
                        SecureField("", text: $text, onCommit: {
                            isFocused = false
                        })
                        .onTapGesture { isFocused = true }
                        .font(SteezFonts.regular(16))
                        .foregroundColor(SteezColors.textPrimary)
                        .padding(.top, (isFocused || !text.isEmpty) ? 12 : 0)
                    }
                }
                
                Button(action: {
                    showPassword.toggle()
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()
                }) {
                    Image(systemName: showPassword ? "eye.slash" : "eye")
                        .foregroundColor(SteezColors.textSecondary)
                        .font(.system(size: 16, weight: .medium))
                }
            }
            .padding(.horizontal, 16)
        }
        .frame(height: 56)
        .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isFocused)
        .animation(.spring(response: 0.2, dampingFraction: 0.8), value: !text.isEmpty)
        .animation(.spring(response: 0.2, dampingFraction: 0.8), value: showPassword)
    }
}

// MARK: - Modern Message Views

struct ModernErrorMessage: View {
    let message: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
            
            Text(message)
                .font(SteezFonts.regular(14))
                .foregroundColor(.white)
                .lineLimit(nil)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [Color.red, Color.red.opacity(0.8)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.red.opacity(0.3), radius: 8, x: 0, y: 4)
    }
}

struct ModernSuccessMessage: View {
    let message: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
            
            Text(message)
                .font(SteezFonts.regular(14))
                .foregroundColor(.white)
                .lineLimit(nil)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [SteezColors.success, SteezColors.success.opacity(0.8)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: SteezColors.success.opacity(0.3), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Helper Extensions

struct ScrollIndicatorModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content.scrollIndicators(.hidden)
        } else {
            content
        }
    }
}

extension View {
    func apply<T: View>(@ViewBuilder _ transform: (Self) -> T) -> T {
        transform(self)
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
