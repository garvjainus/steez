import SwiftUI

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Privacy Policy")
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
                
                // 1. Introduction
                PrivacySection(title: "1. Introduction") {
                    Text("Your privacy is important to us. This Privacy Policy explains how Steez (\"we,\" \"us,\" or \"our\") collects, uses, processes, and protects your personal information when you use our mobile application.")
                    
                    Text("By using our App, you agree to the collection and use of information in accordance with this Privacy Policy.")
                }
                
                // 2. Information We Collect
                PrivacySection(title: "2. Information We Collect") {
                    Text("We collect several types of information:")
                    
                    VStack(alignment: .leading, spacing: 12) {
                        PrivacySubsection(title: "2.1 Personal Information") {
                            Text("• Email address (for account creation)")
                            Text("• Profile information (name, preferences)")
                            Text("• Account credentials")
                        }
                        
                        PrivacySubsection(title: "2.2 Content Data") {
                            Text("• Photos and images you upload")
                            Text("• Fashion preferences and searches")
                            Text("• Wardrobe items and favorites")
                            Text("• Comments and interactions")
                        }
                        
                        PrivacySubsection(title: "2.3 Usage Data") {
                            Text("• App usage patterns and analytics")
                            Text("• Device information (type, OS version)")
                            Text("• IP address and location data (if enabled)")
                            Text("• Crash reports and performance data")
                        }
                        
                        PrivacySubsection(title: "2.4 Third-Party Data") {
                            Text("• Social media profile information (if you connect accounts)")
                            Text("• Shopping data from partner retailers")
                        }
                    }
                }
                
                // 3. How We Use Your Information
                PrivacySection(title: "3. How We Use Your Information") {
                    Text("We use your information to:")
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("• Provide and maintain our services")
                        Text("• Process and analyze fashion images")
                        Text("• Recommend products and content")
                        Text("• Personalize your experience")
                        Text("• Send notifications about deals and updates")
                        Text("• Improve our AI and matching algorithms")
                        Text("• Provide customer support")
                        Text("• Ensure security and prevent fraud")
                        Text("• Comply with legal obligations")
                    }
                    .font(SteezFonts.regular(16))
                    .foregroundColor(SteezColors.textPrimary)
                    .lineSpacing(4)
                }
                
                // 4. Information Sharing
                PrivacySection(title: "4. Information Sharing") {
                    Text("We do not sell your personal information. We may share your information in these limited circumstances:")
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("• With your explicit consent")
                        Text("• With service providers who help us operate the App")
                        Text("• With retailers for product matching (anonymized data only)")
                        Text("• To comply with legal requirements")
                        Text("• To protect our rights and prevent fraud")
                        Text("• In connection with a business transfer or merger")
                    }
                    .font(SteezFonts.regular(16))
                    .foregroundColor(SteezColors.textPrimary)
                    .lineSpacing(4)
                }
                
                // 5. Data Security
                PrivacySection(title: "5. Data Security") {
                    Text("We implement appropriate security measures to protect your information:")
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("• Encryption of data in transit and at rest")
                        Text("• Regular security audits and updates")
                        Text("• Access controls and authentication")
                        Text("• Secure cloud storage with trusted providers")
                        Text("• Regular backups and disaster recovery")
                    }
                    .font(SteezFonts.regular(16))
                    .foregroundColor(SteezColors.textPrimary)
                    .lineSpacing(4)
                    
                    Text("However, no method of transmission over the internet is 100% secure. We cannot guarantee absolute security.")
                }
                
                // 6. Your Rights and Choices
                PrivacySection(title: "6. Your Rights and Choices") {
                    Text("You have the following rights regarding your personal information:")
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("• Access: Request a copy of your data")
                        Text("• Correction: Update or correct your information")
                        Text("• Deletion: Request deletion of your account and data")
                        Text("• Portability: Export your data in a common format")
                        Text("• Objection: Opt out of certain data processing")
                        Text("• Restriction: Limit how we process your data")
                    }
                    .font(SteezFonts.regular(16))
                    .foregroundColor(SteezColors.textPrimary)
                    .lineSpacing(4)
                    
                    Text("To exercise these rights, contact us at privacy@steezapp.com")
                        .foregroundColor(SteezColors.primary)
                }
                
                // 7. Data Retention
                PrivacySection(title: "7. Data Retention") {
                    Text("We retain your information for as long as necessary to provide our services and comply with legal obligations:")
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("• Account data: Until you delete your account")
                        Text("• Upload images: Until you remove them or delete your account")
                        Text("• Usage analytics: Up to 2 years")
                        Text("• Legal compliance data: As required by law")
                    }
                    .font(SteezFonts.regular(16))
                    .foregroundColor(SteezColors.textPrimary)
                    .lineSpacing(4)
                }
                
                // 8. Third-Party Services
                PrivacySection(title: "8. Third-Party Services") {
                    Text("Our App integrates with third-party services:")
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("• Authentication providers (Google, Apple)")
                        Text("• Cloud storage services")
                        Text("• Analytics and crash reporting")
                        Text("• Retailer APIs for product matching")
                        Text("• Payment processors")
                    }
                    .font(SteezFonts.regular(16))
                    .foregroundColor(SteezColors.textPrimary)
                    .lineSpacing(4)
                    
                    Text("These services have their own privacy policies. We encourage you to review them.")
                }
                
                // 9. Children's Privacy
                PrivacySection(title: "9. Children's Privacy") {
                    Text("Our App is not intended for children under 13 years of age. We do not knowingly collect personal information from children under 13. If we become aware that we have collected personal information from a child under 13, we will take steps to delete such information.")
                }
                
                // 10. International Data Transfers
                PrivacySection(title: "10. International Data Transfers") {
                    Text("Your information may be transferred to and processed in countries other than your own. We ensure appropriate safeguards are in place to protect your data in accordance with this Privacy Policy.")
                }
                
                // 11. Cookie and Tracking Technologies
                PrivacySection(title: "11. Cookies and Tracking") {
                    Text("We use various technologies to collect and store information:")
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("• Local storage for app preferences")
                        Text("• Analytics for app performance")
                        Text("• Crash reporting for stability")
                        Text("• Push notification tokens")
                    }
                    .font(SteezFonts.regular(16))
                    .foregroundColor(SteezColors.textPrimary)
                    .lineSpacing(4)
                    
                    Text("You can control some of these through your device settings.")
                }
                
                // 12. Changes to Privacy Policy
                PrivacySection(title: "12. Changes to This Policy") {
                    Text("We may update this Privacy Policy from time to time. We will notify you of any significant changes by:")
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("• Sending you an email notification")
                        Text("• Posting a notice in the App")
                        Text("• Updating the \"Last updated\" date")
                    }
                    .font(SteezFonts.regular(16))
                    .foregroundColor(SteezColors.textPrimary)
                    .lineSpacing(4)
                    
                    Text("Continued use of the App after changes constitutes acceptance of the updated policy.")
                }
                
                // 13. Contact Information
                PrivacySection(title: "13. Contact Us") {
                    Text("If you have any questions about this Privacy Policy or our data practices, please contact us:")
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Email: privacy@steezapp.com")
                        Text("Data Protection Officer: dpo@steezapp.com")
                        Text("Address: [Your Business Address]")
                    }
                    .font(SteezFonts.regular(16))
                    .foregroundColor(SteezColors.primary)
                    
                    Text("We will respond to your inquiry within 30 days.")
                }
                
                Spacer(minLength: 40)
            }
            .padding(24)
        }
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
        .background(SteezColors.background)
    }
}

// MARK: - Privacy Section Component
struct PrivacySection<Content: View>: View {
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

// MARK: - Privacy Subsection Component
struct PrivacySubsection<Content: View>: View {
    let title: String
    let content: () -> Content
    
    init(title: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(SteezFonts.medium(16))
                .foregroundColor(SteezColors.textPrimary)
            
            VStack(alignment: .leading, spacing: 6) {
                content()
            }
            .font(SteezFonts.regular(16))
            .foregroundColor(SteezColors.textPrimary)
            .lineSpacing(4)
        }
        .padding(.leading, 16)
    }
}

#Preview {
    NavigationView {
        PrivacyPolicyView()
    }
}

#Preview {
    NavigationView {
        PrivacyPolicyView()
    }
} 