import SwiftUI

// MARK: - Legal Consent View
struct LegalConsentView: View {
    @State private var showingTerms = false
    @State private var showingPrivacy = false
    
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 4) {
                Text("By continuing, you agree to our")
                    .font(SteezFonts.regular(14))
                    .foregroundColor(SteezColors.textSecondary)
                
                Button(action: { showingTerms = true }) {
                    Text("Terms of Service")
                        .font(SteezFonts.regular(14))
                        .foregroundColor(SteezColors.primary)
                        .underline()
                }
                .buttonStyle(PlainButtonStyle())
                
                Text("and")
                    .font(SteezFonts.regular(14))
                    .foregroundColor(SteezColors.textSecondary)
                
                Button(action: { showingPrivacy = true }) {
                    Text("Privacy Policy")
                        .font(SteezFonts.regular(14))
                        .foregroundColor(SteezColors.primary)
                        .underline()
                }
                .buttonStyle(PlainButtonStyle())
            }
            .multilineTextAlignment(.center)
            .lineLimit(2)
        }
        .sheet(isPresented: $showingTerms) {
            NavigationView {
                TermsOfServiceView()
                    .navigationBarItems(
                        trailing: Button("Done") {
                            showingTerms = false
                        }
                    )
            }
        }
        .sheet(isPresented: $showingPrivacy) {
            NavigationView {
                PrivacyPolicyView()
                    .navigationBarItems(
                        trailing: Button("Done") {
                            showingPrivacy = false
                        }
                    )
            }
        }
    }
}

// MARK: - Previews
#if DEBUG
struct LegalConsentView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            LegalConsentView()
        }
        .padding()
        .background(SteezColors.background)
    }
}
#endif
