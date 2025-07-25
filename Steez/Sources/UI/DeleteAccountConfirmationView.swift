import SwiftUI

struct DeleteAccountConfirmationView: View {
    @Binding var isPresented: Bool
    let userEmail: String
    @Binding var input: String
    let onConfirm: () -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Text("Delete Account")
                    .font(SteezFonts.medium(24))
                
                Text("Type your email (\(userEmail)) to confirm deletion. This action cannot be undone.")
                    .font(SteezFonts.regular(15))
                    .multilineTextAlignment(.center)
                
                TextField("Email", text: $input)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .padding(.horizontal)
                
                Button(role: .destructive, action: {
                    onConfirm()
                    isPresented = false
                }) {
                    Text("Delete Account")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(input == userEmail ? Color.red : Color.gray.opacity(0.4))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .disabled(input != userEmail)
                
                Spacer()
            }
            .padding()
            .navigationBarItems(leading: Button("Cancel") {
                isPresented = false
            })
        }
    }
}

#Preview {
    DeleteAccountConfirmationView(isPresented: .constant(true), userEmail: "user@example.com", input: .constant("")) {}
} 