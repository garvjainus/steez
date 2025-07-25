import SwiftUI

struct TermsOfServiceView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Terms of Service")
                    .font(SteezFonts.medium(28))
                    .padding(.bottom, 8)
                
                Text("Last updated: \(Date().formatted(date: .long, time: .omitted))")
                    .font(SteezFonts.regular(14))
                    .foregroundColor(SteezColors.textSecondary)
                    .padding(.bottom, 16)
                
                Text("Agreement to Terms")
                    .font(SteezFonts.medium(20))
                
                Text("By using our app, you agree to be bound by these Terms of Service. If you do not agree to these terms, do not use the app.")
                    .font(SteezFonts.regular(16))
                    .lineSpacing(6)
                
                Text("User Accounts")
                    .font(SteezFonts.medium(20))
                    .padding(.top, 16)
                
                Text("When you create an account with us, you must provide us information that is accurate, complete, and current at all times. Failure to do so constitutes a breach of the Terms, which may result in immediate termination of your account on our service.")
                    .font(SteezFonts.regular(16))
                    .lineSpacing(6)
                    
                Text("Termination")
                    .font(SteezFonts.medium(20))
                    .padding(.top, 16)
                
                Text("We may terminate or suspend your account immediately, without prior notice or liability, for any reason whatsoever, including without limitation if you breach the Terms.")
                    .font(SteezFonts.regular(16))
                    .lineSpacing(6)
                
                Spacer()
            }
            .padding(24)
        }
        .navigationTitle("Terms of Service")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationView {
        TermsOfServiceView()
    }
} 