import SwiftUI

// MARK: - Tab Bar Types
enum MainTab: String, CaseIterable {
    case discover = "Discover"
    case importTab = "Import"
    case profile = "Profile"
    
    var icon: String {
        switch self {
        case .discover: return "sparkles"
        case .importTab: return "plus.circle.fill"
        case .profile: return "person.circle"
        }
    }
    
    var fillIcon: String {
        switch self {
        case .discover: return "sparkles"
        case .importTab: return "plus.circle.fill"
        case .profile: return "person.circle.fill"
        }
    }
}

// MARK: - Custom Tab Bar
struct CustomTabBar: View {
    @Binding var selectedTab: Int // Changed to Int
    @State private var tabItemFrames: [Int: CGRect] = [:] // Use Int as key
    
    private let tabs = MainTab.allCases
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs.indices, id: \.self) { index in
                let tab = tabs[index]
                TabBarItem(
                    tab: tab,
                    isSelected: selectedTab == index,
                    action: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            selectedTab = index
                        }
                        
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                    }
                )
                .background(
                    GeometryReader { geometry in
                        Color.clear
                            .onAppear {
                                tabItemFrames[index] = geometry.frame(in: .named("TabBarContainer"))
                            }
                    }
                )
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(SteezColors.cardBackground)
                .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: -5)
        )
        .padding(.horizontal, 24)
        .padding(.bottom, 8)
        .coordinateSpace(name: "TabBarContainer")
    }
}

struct TabBarItem: View {
    let tab: MainTab
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: isSelected ? tab.fillIcon : tab.icon)
                    .font(.system(size: tab == .importTab ? 28 : 22, weight: .medium))
                    .foregroundColor(isSelected ? SteezColors.primary : SteezColors.textSecondary)
                    .scaleEffect(isSelected ? 1.1 : 1.0)
                
                if tab != .importTab {
                    Text(tab.rawValue)
                        .font(SteezFonts.regular(12))
                        .foregroundColor(isSelected ? SteezColors.primary : SteezColors.textSecondary)
                        .opacity(isSelected ? 1.0 : 0.7)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSelected)
    }
} 