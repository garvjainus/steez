import SwiftUI

// Color extension defined in UserPreferencesView

struct LandingPageView: View {
    @EnvironmentObject var appState: AppState
    @State private var titleAnimated = false
    @State private var logoAnimated = false
    @State private var textAnimated = false
    @State private var buttonAnimated = false
    @State private var backgroundAnimated = false
    @State private var logoScale: CGFloat = 0.3
    @State private var logoRotation: Double = 0
    @State private var showSparkles = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Animated background
                Color(hex: "FCFCFC")
                    .ignoresSafeArea()
                
                /*Floating particles background
                ForEach(0..<6, id: \.self) { i in
                    Circle()
                        .fill(Color(red: 0.54, green: 0.17, blue: 0.22).opacity(0.1))
                        .frame(width: CGFloat.random(in: 20...60))
                        .offset(
                            x: CGFloat.random(in: -200...200),
                            y: CGFloat.random(in: -300...300)
                        )
                        .scaleEffect(backgroundAnimated ? 1.2 : 0.8)
                        .animation(
                            .easeInOut(duration: Double.random(in: 2...4))
                            .repeatForever(autoreverses: true)
                            .delay(Double(i) * 0.5),
                            value: backgroundAnimated
                        )
                }
                 */
                
                VStack(spacing: 10) {
                    // Top: Title
                    HStack(spacing: 1) {
                        ForEach(Array("Steez".enumerated()), id: \.offset) { index, character in
                            Text(String(character))
                                .font(.custom("IBMPlexMono-Medium", size: 72))
                                .foregroundColor(.black)
                                .opacity(titleAnimated ? 1.0 : 0.0)
                                .offset(y: titleAnimated ? 0 : -50)
                                .rotationEffect(.degrees(titleAnimated ? 0 : Double.random(in: -15...15)))
                                .animation(
                                    .spring(response: 0.8, dampingFraction: 0.6)
                                    .delay(Double(index) * 0.1),
                                    value: titleAnimated
                                )
                        }
                    }
                    .padding(.top, 20) // Add some padding from the top edge

                    
                    // Center: Logo
                    SteezLogo()
                        .padding(.top, 10)
                        .padding(.bottom, 20)
                    
                    // Bottom: Call to Action
                    VStack(spacing: 16) {
                        Text("Let's fix your wardrobe.")
                            .font(.custom("IBMPlexSans-Medium", size: 28))
                            .foregroundColor(.black)
                            .opacity(textAnimated ? 1.0 : 0.0)
                            .offset(y: textAnimated ? 0 : 30)
                            .animation(.easeOut(duration: 0.8).delay(0.3), value: textAnimated)
                        
                        HStack {
                            Text("1000s of fits identified!")
                                .font(.custom("IBMPlexSans-Regular", size: 18))
                                .foregroundColor(.gray)
                            
                            // Sparkle animation
                            if showSparkles {
                                Image(systemName: "sparkles")
                                    .foregroundColor(Color(red: 0.54, green: 0.17, blue: 0.22))
                                    .scaleEffect(showSparkles ? 1.2 : 0.8)
                                    .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: showSparkles)
                            }
                        }
                        .opacity(textAnimated ? 1.0 : 0.0)
                        .offset(y: textAnimated ? 0 : 30)
                        .animation(.easeOut(duration: 0.8).delay(0.3), value: textAnimated)
                    }
                    .padding(.bottom, 32)
                    
                    // Enhanced Get Started button
                    Button(action: {
                        // Haptic feedback
                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                        impactFeedback.impactOccurred()
                        
                        // Navigate with animation
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            appState.completeLanding()
                        }
                    }) {
                        HStack(spacing: 12) {
                            Text("Get Started")
                                .font(.custom("IBMPlexSans-Medium", size: 18))
                            
                            Image(systemName: "arrow.right")
                                .font(.system(size: 16, weight: .medium))
                                .offset(x: buttonAnimated ? 5 : 0)
                                .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: buttonAnimated)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.54, green: 0.17, blue: 0.22),
                                    Color(red: 0.64, green: 0.27, blue: 0.32)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(28)
                        .shadow(color: Color(red: 0.54, green: 0.17, blue: 0.22).opacity(0.3), radius: 10, x: 0, y: 5)
                        .scaleEffect(buttonAnimated ? 1.0 : 0.9)
                        .opacity(buttonAnimated ? 1.0 : 0.0)
                        .animation(.spring(response: 0.8, dampingFraction: 0.6).delay(0.4), value: buttonAnimated)
                    }
                    .buttonStyle(PressableButtonStyle())
                    .padding(.horizontal, 40)
                    .padding(.bottom, geometry.safeAreaInsets.bottom > 0 ? 0 : 20) // Add bottom padding only if no safe area
                }
            }
        }
        .onAppear {
            // Trigger animations sequentially
            withAnimation {
                titleAnimated = true
                backgroundAnimated = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                withAnimation {
                    logoAnimated = true
                    logoScale = 1.0
                }
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                withAnimation {
                    textAnimated = true
                    showSparkles = true
                }
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                withAnimation {
                    buttonAnimated = true
                }
            }
        }
    }
}

// PressableButtonStyle defined in UserPreferencesView

struct SteezLogo: View {
    var body: some View {
        Image("steezlogo")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(maxWidth: 300) // Use maxWidth to allow flexibility
    }
}

#Preview {
    LandingPageView()
        .environmentObject(AppState())
} 
