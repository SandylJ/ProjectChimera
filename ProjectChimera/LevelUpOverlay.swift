import SwiftUI

struct LevelUpOverlay: View {
    @Binding var didLevelUp: Bool
    
    var body: some View {
        ZStack {
            if didLevelUp {
                // Simple level up overlay without iOS-specific features
                Text("Level Up!")
                    .font(.largeTitle.bold())
                    .padding(24)
                    .background(.ultraThinMaterial, in: Capsule())
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            didLevelUp = false
                        }
                    }
            }
        }
    }
}
