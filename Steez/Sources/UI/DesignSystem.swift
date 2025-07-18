import SwiftUI

// MARK: - Design System
struct SteezColors {
    static let primary = Color(red: 0.54, green: 0.17, blue: 0.22)
    static let primaryLight = Color(red: 0.64, green: 0.27, blue: 0.32)
    static let background = Color(hex: "FCFCFC")
    static let cardBackground = Color.white
    static let textPrimary = Color.black
    static let textSecondary = Color.gray
    static let success = Color.green
    static let error = Color.red
}

struct SteezFonts {
    static func regular(_ size: CGFloat) -> Font {
        .custom("IBMPlexSans-Regular", size: size)
    }
    
    static func medium(_ size: CGFloat) -> Font {
        .custom("IBMPlexSans-Medium", size: size)
    }
    
    static func mono(_ size: CGFloat) -> Font {
        .custom("IBMPlexMono-Medium", size: size)
    }
}

// MARK: - Button Styles
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(SteezFonts.medium(16))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                LinearGradient(
                    colors: [SteezColors.primary, SteezColors.primaryLight],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(16)
            .shadow(color: SteezColors.primary.opacity(0.3), radius: 8, x: 0, y: 4)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(SteezFonts.medium(16))
            .foregroundColor(SteezColors.primary)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(SteezColors.primary.opacity(0.1))
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Text Field Style
struct ModernTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(SteezColors.cardBackground)
                    .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
            )
    }
}

// MARK: - Reusable Components
struct QuickActionCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.1))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: icon)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(color)
                }
                
                VStack(spacing: 4) {
                    Text(title)
                        .font(SteezFonts.medium(16))
                        .foregroundColor(SteezColors.textPrimary)
                    
                    Text(subtitle)
                        .font(SteezFonts.regular(12))
                        .foregroundColor(SteezColors.textSecondary)
                }
            }
            .frame(height: 140)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(SteezColors.cardBackground)
                    .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 2)
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
} 