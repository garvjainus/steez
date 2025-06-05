import SwiftUI

struct LandingPageView: View {
    @State private var currentPage = 0
    @EnvironmentObject var appState: AppState
    
    private let features = [
        OnboardingFeature(
            icon: "camera.fill",
            title: "Snap & Discover",
            description: "Take a photo of any clothing item and discover where to buy it",
            gradient: LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
        ),
        OnboardingFeature(
            icon: "sparkles",
            title: "AI-Powered Search",
            description: "Our advanced Google Lens integration finds similar items instantly",
            gradient: LinearGradient(colors: [.purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
        ),
        OnboardingFeature(
            icon: "bag.fill",
            title: "Shop Smart",
            description: "Compare prices across multiple retailers and find the best deals",
            gradient: LinearGradient(colors: [.pink, .orange], startPoint: .topLeading, endPoint: .bottomTrailing)
        )
    ]
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [.black, .gray.opacity(0.8)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Logo and App Name
                headerView
                
                // Feature Cards
                TabView(selection: $currentPage) {
                    ForEach(0..<features.count, id: \.self) { index in
                        FeatureCardView(feature: features[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
                .frame(height: 400)
                .padding(.horizontal)
                
                Spacer(minLength: 50)
                
                // Page indicators and buttons
                bottomView
            }
            .padding(.vertical, 50)
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 20) {
            // App Icon
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundColor(.white)
            }
            .shadow(color: .blue.opacity(0.3), radius: 10, x: 0, y: 5)
            
            // App Name
            Text("Steez")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.white, .gray.opacity(0.8)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            
            Text("Find your style, anywhere")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 20)
    }
    
    private var bottomView: some View {
        VStack(spacing: 30) {
            // Custom page indicator
            HStack(spacing: 8) {
                ForEach(0..<features.count, id: \.self) { index in
                    Capsule()
                        .fill(currentPage == index ? Color.white : Color.gray.opacity(0.4))
                        .frame(width: currentPage == index ? 24 : 8, height: 8)
                        .animation(.easeInOut(duration: 0.3), value: currentPage)
                }
            }
            
            // Action buttons
            VStack(spacing: 16) {
                // Get Started button
                Button(action: {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        appState.completeOnboarding()
                    }
                }) {
                    HStack {
                        Text("Get Started")
                            .font(.system(size: 18, weight: .semibold))
                        
                        Image(systemName: "arrow.right")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(28)
                    .shadow(color: .blue.opacity(0.3), radius: 10, x: 0, y: 5)
                }
                .scaleEffect(currentPage == features.count - 1 ? 1.0 : 0.95)
                .animation(.easeInOut(duration: 0.3), value: currentPage)
                
                // Skip button
                Button(action: {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        appState.completeOnboarding()
                    }
                }) {
                    Text("Skip for now")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.gray)
                }
            }
            .padding(.horizontal, 32)
        }
    }
}

struct FeatureCardView: View {
    let feature: OnboardingFeature
    
    var body: some View {
        VStack(spacing: 24) {
            // Icon
            ZStack {
                Circle()
                    .fill(feature.gradient)
                    .frame(width: 100, height: 100)
                    .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                
                Image(systemName: feature.icon)
                    .font(.system(size: 48, weight: .medium))
                    .foregroundColor(.white)
            }
            
            VStack(spacing: 16) {
                Text(feature.title)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Text(feature.description)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .padding(.horizontal, 20)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

struct OnboardingFeature {
    let icon: String
    let title: String
    let description: String
    let gradient: LinearGradient
}

#Preview {
    LandingPageView()
} 