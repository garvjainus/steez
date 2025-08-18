import SwiftUI

struct TermsOfServiceView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Terms of Service")
                        .font(SteezFonts.medium(28))
                        .foregroundColor(SteezColors.textPrimary)
                    
                    Text("Last updated: January 1, 2025")
                        .font(SteezFonts.regular(14))
                        .foregroundColor(SteezColors.textSecondary)
                    
                    Text("Version 1.0")
                        .font(SteezFonts.regular(12))
                        .foregroundColor(SteezColors.textSecondary)
                }
                .padding(.bottom, 16)
                
                // 1. Agreement to Terms
                TermsSection(title: "1. Agreement to Terms") {
                    Text("By downloading, accessing, or using the Steez mobile application (\"App\"), you agree to be bound by these Terms of Service (\"Terms\"). If you do not agree to these Terms, do not use the App.")
                    
                    Text("These Terms constitute a legally binding agreement between you and Steez regarding your use of the App.")
                }
                
                // 2. Description of Service
                TermsSection(title: "2. Description of Service") {
                    Text("Steez is a fashion discovery and wardrobe management application that allows users to:")
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("• Upload and analyze fashion images")
                        Text("• Discover similar clothing items from retailers")
                        Text("• Organize their digital wardrobe")
                        Text("• Track price changes and deals")
                        Text("• Share fashion content with other users")
                    }
                    .font(SteezFonts.regular(16))
                    .foregroundColor(SteezColors.textPrimary)
                    .lineSpacing(4)
                }
                
                // 3. User Accounts
                TermsSection(title: "3. User Accounts") {
                    Text("To access certain features, you must create an account. You agree to:")
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("• Provide accurate, current, and complete information")
                        Text("• Maintain the security of your account credentials")
                        Text("• Accept responsibility for all activities under your account")
                        Text("• Notify us immediately of any security breaches")
                    }
                    .font(SteezFonts.regular(16))
                    .foregroundColor(SteezColors.textPrimary)
                    .lineSpacing(4)
                    
                    Text("You are responsible for maintaining the confidentiality of your account and password.")
                }
                
                // 4. User Content
                TermsSection(title: "4. User Content") {
                    Text("You retain ownership of content you submit, but grant us a license to use it for providing our services. You agree not to upload content that:")
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("• Violates intellectual property rights")
                        Text("• Contains harmful, offensive, or illegal material")
                        Text("• Violates privacy rights of others")
                        Text("• Contains malware or viruses")
                    }
                    .font(SteezFonts.regular(16))
                    .foregroundColor(SteezColors.textPrimary)
                    .lineSpacing(4)
                }
                
                // 5. Privacy and Data
                TermsSection(title: "5. Privacy and Data") {
                    Text("Your privacy is important to us. Our Privacy Policy explains how we collect, use, and protect your information. By using the App, you consent to our data practices as described in our Privacy Policy.")
                }
                
                // 6. Intellectual Property
                TermsSection(title: "6. Intellectual Property") {
                    Text("The App and its original content, features, and functionality are owned by Steez and are protected by international copyright, trademark, and other intellectual property laws.")
                }
                
                // 7. Prohibited Uses
                TermsSection(title: "7. Prohibited Uses") {
                    Text("You may not use the App to:")
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("• Violate any laws or regulations")
                        Text("• Harass, abuse, or harm other users")
                        Text("• Impersonate others or provide false information")
                        Text("• Interfere with or disrupt the App's functionality")
                        Text("• Attempt to gain unauthorized access to our systems")
                        Text("• Use automated systems to access the App")
                    }
                    .font(SteezFonts.regular(16))
                    .foregroundColor(SteezColors.textPrimary)
                    .lineSpacing(4)
                }
                
                // 8. Third-Party Services
                TermsSection(title: "8. Third-Party Services") {
                    Text("Our App may link to third-party websites or services. We are not responsible for the content, privacy policies, or practices of third-party sites. Use of third-party services is at your own risk.")
                }
                
                // 9. Disclaimers and Limitations
                TermsSection(title: "9. Disclaimers and Limitations") {
                    Text("THE APP IS PROVIDED \"AS IS\" WITHOUT WARRANTIES OF ANY KIND. WE DISCLAIM ALL WARRANTIES, EXPRESS OR IMPLIED, INCLUDING MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.")
                    
                    Text("WE SHALL NOT BE LIABLE FOR ANY INDIRECT, INCIDENTAL, SPECIAL, OR CONSEQUENTIAL DAMAGES ARISING FROM YOUR USE OF THE APP.")
                }
                
                // 10. Termination
                TermsSection(title: "10. Termination") {
                    Text("We may terminate or suspend your account and access to the App immediately, without prior notice, for any reason, including breach of these Terms.")
                    
                    Text("Upon termination, your right to use the App will cease immediately. All provisions that should survive termination shall survive.")
                }
                
                // 11. Changes to Terms
                TermsSection(title: "11. Changes to Terms") {
                    Text("We reserve the right to modify these Terms at any time. We will notify users of significant changes via the App or email. Continued use after changes constitutes acceptance of the new Terms.")
                }
                
                // 12. Governing Law
                TermsSection(title: "12. Governing Law") {
                    Text("These Terms are governed by and construed in accordance with the laws of [Your Jurisdiction], without regard to conflict of law principles.")
                }
                
                // 13. Contact Information
                TermsSection(title: "13. Contact Information") {
                    Text("If you have any questions about these Terms, please contact us at:")
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Email: legal@steezapp.com")
                        Text("Address: [Your Business Address]")
                    }
                    .font(SteezFonts.regular(16))
                    .foregroundColor(SteezColors.primary)
                }
                
                Spacer(minLength: 40)
            }
            .padding(24)
        }
        .navigationTitle("Terms of Service")
        .navigationBarTitleDisplayMode(.inline)
        .background(SteezColors.background)
    }
}

// MARK: - Terms Section Component
struct TermsSection<Content: View>: View {
    let title: String
    let content: () -> Content
    
    init(title: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(SteezFonts.medium(18))
                .foregroundColor(SteezColors.textPrimary)
            
            VStack(alignment: .leading, spacing: 12) {
                content()
            }
            .font(SteezFonts.regular(16))
            .foregroundColor(SteezColors.textPrimary)
            .lineSpacing(6)
        }
    }
}

#Preview {
    NavigationView {
        TermsOfServiceView()
    }
} 