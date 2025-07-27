import SwiftUI

struct DeleteAccountConfirmationView: View {
    @Binding var isPresented: Bool
    let userEmail: String
    @Binding var input: String
    let onConfirm: () -> Void
    
    @State private var isLoading = false
    @State private var showingFinalWarning = false
    
    private var inputMatches: Bool {
        input.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == userEmail.lowercased()
    }
    
    var body: some View {
        ZStack {
            // Background - full screen coverage
            Color.black.opacity(0.4)
                .ignoresSafeArea(.all)
            
            // Main content
            VStack(spacing: 0) {
                // Card
                VStack(spacing: 0) {
                    // Header with warning icon
                    VStack(spacing: 20) {
                        // Warning icon
                        ZStack {
                            Circle()
                                .fill(Color.red.opacity(0.1))
                                .frame(width: 80, height: 80)
                            
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 36, weight: .medium))
                                .foregroundColor(.red)
                        }
                        
                        VStack(spacing: 12) {
                            Text("Delete Account")
                                .font(SteezFonts.medium(28))
                                .foregroundColor(SteezColors.textPrimary)
                            
                            Text("This is permanent and cannot be undone")
                                .font(SteezFonts.regular(16))
                                .foregroundColor(SteezColors.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.top, 32)
                    .padding(.horizontal, 24)
                    
                    // Warning message
                    VStack(spacing: 16) {
                        Text("All data will be permanently deleted:")
                            .font(SteezFonts.medium(16))
                            .foregroundColor(SteezColors.textPrimary)
                            .lineLimit(1)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.red)
                                    .font(.system(size: 14, weight: .medium))
                                    .padding(.top, 1)
                                Text("Wardrobe & saved items")
                                    .font(SteezFonts.regular(15))
                                    .foregroundColor(SteezColors.textSecondary)
                                    .lineLimit(1)
                                Spacer(minLength: 0)
                            }
                            
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.red)
                                    .font(.system(size: 14, weight: .medium))
                                    .padding(.top, 1)
                                Text("Account preferences")
                                    .font(SteezFonts.regular(15))
                                    .foregroundColor(SteezColors.textSecondary)
                                    .lineLimit(1)
                                Spacer(minLength: 0)
                            }
                            
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.red)
                                    .font(.system(size: 14, weight: .medium))
                                    .padding(.top, 1)
                                Text("Data & history")
                                    .font(SteezFonts.regular(15))
                                    .foregroundColor(SteezColors.textSecondary)
                                    .lineLimit(1)
                                Spacer(minLength: 0)
                            }
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 18)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.red.opacity(0.05))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.red.opacity(0.2), lineWidth: 1)
                                )
                        )
                    }
                    .padding(.top, 28)
                    .padding(.horizontal, 24)
                    
                    // Confirmation input section
                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Type your email to confirm:")
                                .font(SteezFonts.medium(16))
                                .foregroundColor(SteezColors.textPrimary)
                                .lineLimit(1)
                            
                            Text(userEmail)
                                .font(SteezFonts.regular(14))
                                .foregroundColor(SteezColors.primary)
                                .lineLimit(1)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(SteezColors.primary.opacity(0.1))
                                )
                        }
                        
                        // Custom styled text field
                        VStack(alignment: .leading, spacing: 10) {
                            TextField("Enter your email address", text: $input)
                                .font(SteezFonts.regular(16))
                                .foregroundColor(SteezColors.textPrimary)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                                .keyboardType(.emailAddress)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(SteezColors.surface)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(
                                                    inputMatches ? Color.red : (input.isEmpty ? Color.gray.opacity(0.3) : Color.red.opacity(0.5)),
                                                    lineWidth: inputMatches ? 2 : 1
                                                )
                                        )
                                )
                            
                            if !input.isEmpty && !inputMatches {
                                HStack(spacing: 8) {
                                    Image(systemName: "exclamationmark.circle.fill")
                                        .foregroundColor(.red)
                                        .font(.system(size: 12))
                                    Text("Email doesn't match")
                                        .font(SteezFonts.regular(12))
                                        .foregroundColor(.red)
                                        .lineLimit(1)
                                }
                                .padding(.horizontal, 4)
                            }
                        }
                    }
                    .padding(.top, 28)
                    .padding(.horizontal, 24)
                    
                    // Action buttons
                    VStack(spacing: 16) {
                        // Delete button
                        Button(action: {
                            if inputMatches {
                                showingFinalWarning = true
                            }
                        }) {
                            HStack(spacing: 12) {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "trash.fill")
                                        .font(.system(size: 16, weight: .medium))
                                    
                                    Text("Delete My Account")
                                        .font(SteezFonts.medium(17))
                                        .lineLimit(1)
                                }
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(
                                RoundedRectangle(cornerRadius: 27)
                                    .fill(inputMatches ? Color.red : Color.gray.opacity(0.3))
                            )
                            .scaleEffect(inputMatches ? 1.0 : 0.98)
                            .opacity(inputMatches ? 1.0 : 0.6)
                        }
                        .disabled(!inputMatches || isLoading)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: inputMatches)
                        
                        // Cancel button
                        Button(action: {
                            isPresented = false
                        }) {
                            Text("Cancel")
                                .font(SteezFonts.medium(16))
                                .foregroundColor(SteezColors.textSecondary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .lineLimit(1)
                        }
                        .disabled(isLoading)
                    }
                    .padding(.top, 32)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                }
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(SteezColors.background)
                        .shadow(color: .black.opacity(0.15), radius: 30, x: 0, y: 15)
                )
                .padding(.horizontal, 20)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .alert("Final Warning", isPresented: $showingFinalWarning) {
            Button("Delete Forever", role: .destructive) {
                performDeletion()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you absolutely sure? This cannot be undone and all your data will be permanently lost.")
        }
    }
    
    private func performDeletion() {
        isLoading = true
        
        // Add haptic feedback
        let notification = UINotificationFeedbackGenerator()
        notification.notificationOccurred(.warning)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            onConfirm()
            isPresented = false
            isLoading = false
        }
    }
}

#Preview {
    DeleteAccountConfirmationView(
        isPresented: .constant(true), 
        userEmail: "user@example.com", 
        input: .constant("")
    ) {}
} 