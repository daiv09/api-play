import SwiftUI

struct SplashView: View {
    @Bindable var coordinator: AppLifecycleCoordinator
    
    // Animation States
    @State private var iconScale: CGFloat = 0.65
    @State private var iconBlur: CGFloat = 10.0
    @State private var iconOpacity: Double = 0.0
    @State private var iconShadowOpacity: Double = 0.0
    
    var body: some View {
        ZStack {
            Color.white
                .ignoresSafeArea()
            
            RadialGradient(
                colors: [
                    Color.primary.opacity(0.03),
                    .clear
                ],
                center: .center,
                startRadius: 10,
                endRadius: 300
            )
            .ignoresSafeArea()
            
            VStack(spacing: 24) {
                #if os(macOS)
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 128, height: 128)
                    .scaleEffect(iconScale)
                    .blur(radius: iconBlur)
                    .opacity(iconOpacity)
                    .shadow(
                        color: .black.opacity(iconShadowOpacity),
                        radius: 15,
                        y: 10
                    )
                #else
                Image(systemName: "app.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 128, height: 128)
                    .scaleEffect(iconScale)
                    .blur(radius: iconBlur)
                    .opacity(iconOpacity)
                    .shadow(
                        color: .black.opacity(iconShadowOpacity),
                        radius: 15,
                        y: 10
                    )
                #endif
                
                Text(coordinator.state.rawValue)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText()) // Smoothly transition text
                    .animation(.spring(response: 0.45, dampingFraction: 0.82), value: coordinator.state)
            }
        }
        .onAppear {
            withAnimation(
                .interpolatingSpring(
                    mass: 1,
                    stiffness: 90,
                    damping: 12
                )
            ) {
                iconScale = 1
                iconBlur = 0
                iconOpacity = 1
                iconShadowOpacity = 0.15
            }
        }
    }
}
