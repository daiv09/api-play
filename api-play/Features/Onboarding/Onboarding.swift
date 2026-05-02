import SwiftUI

struct OnboardingStep: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let image: String
    let color: Color
}

struct OnboardingView: View {
    @Binding var isShowing: Bool
    @State private var currentStep = 0
    
    let steps = [
        OnboardingStep(title: "Rapid Requests", description: "Craft complex API calls with a clean, native interface designed for speed.", image: "bolt.fill", color: .orange),
        OnboardingStep(title: "Environment Sync", description: "Switch between environments effortlessly using {{variable}} injection.", image: "arrow.3.trianglepath", color: .blue),
        OnboardingStep(title: "Inspect Deeply", description: "Visualize JSON structures with a high-performance native tree view.", image: "doc.text.magnifyingglass", color: .purple)
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Main Content Area
            VStack(spacing: 40) {
                // Static Hero Image
                Image(systemName: steps[currentStep].image)
                    .font(.system(size: 80, weight: .light))
                    .foregroundStyle(steps[currentStep].color)
                    .frame(height: 120)
                    .padding(.top, 60)
                
                VStack(spacing: 16) {
                    Text(steps[currentStep].title)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                    
                    Text(steps[currentStep].description)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 60)
                }
            }
            
            Spacer()
            
            // Footer Navigation
            HStack {
                // Simple Page Indicator
                HStack(spacing: 8) {
                    ForEach(0..<steps.count, id: \.self) { i in
                        Circle()
                            .fill(i == currentStep ? steps[currentStep].color : Color.secondary.opacity(0.3))
                            .frame(width: 8, height: 8)
                    }
                }
                
                Spacer()
                
                // Action Buttons
                HStack(spacing: 12) {
                    if currentStep < steps.count - 1 {
                        Button("Skip") {
                            isShowing = false
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                    }
                    
                    Button(action: nextStep) {
                        Text(currentStep == steps.count - 1 ? "Get Started" : "Continue")
                            .frame(width: 100)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(steps[currentStep].color)
                    .controlSize(.large)
                }
            }
            .padding(40)
        }
        .frame(width: 600, height: 450)
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    private func nextStep() {
        if currentStep < steps.count - 1 {
            currentStep += 1
        } else {
            isShowing = false
        }
    }
}
