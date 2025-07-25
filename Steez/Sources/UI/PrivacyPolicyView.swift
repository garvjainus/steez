import SwiftUI

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Privacy Policy")
                    .font(SteezFonts.medium(28))
                    .padding(.bottom, 8)
                
                Text("Last updated: \(Date().formatted(date: .long, time: .omitted))")
                    .font(SteezFonts.regular(14))
                    .foregroundColor(SteezColors.textSecondary)
                    .padding(.bottom, 16)
                
                Text("Introduction")
                    .font(SteezFonts.medium(20))
                
                Text("Your privacy is important to us. This privacy statement explains the personal data Steez processes, how Steez processes it, and for what purposes.")
                    .font(SteezFonts.regular(16))
                    .lineSpacing(6)
                
                Text("Information We Collect")
                    .font(SteezFonts.medium(20))
                    .padding(.top, 16)
                
                Text("Steez collects data to operate effectively and provide you the best experiences with our services. You provide some of this data directly, such as when you create a Steez account.")
                    .font(SteezFonts.regular(16))
                    .lineSpacing(6)
                    
                Text("How We Use Information")
                    .font(SteezFonts.medium(20))
                    .padding(.top, 16)
                
                Text("Steez uses the data we collect to provide you with rich, interactive experiences. In particular, we use data to: \n\n- Provide our services, which includes updating, securing, and troubleshooting, as well as providing support. \n- Improve and develop our services. \n- Personalize our services and make recommendations.")
                    .font(SteezFonts.regular(16))
                    .lineSpacing(6)
                
                Spacer()
            }
            .padding(24)
        }
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationView {
        PrivacyPolicyView()
    }
} 