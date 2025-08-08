import SwiftUI

struct MainTabs: View {
    @State private var gameState = GameState()
    @StateObject private var ascension = AscensionManager()
    @StateObject private var challenges = DailyChallengeManager(hooks: nil)

    @State private var bridge: ChallengeBridge?

    var body: some View {
        TabView {
            // Swap this for your real home/root once ready
            HomePlaceholderView()
                .tabItem { Label("Home", systemImage: "house") }

            AscensionView(ascension: ascension, state: $gameState)
                .tabItem { Label("Ascend", systemImage: "arrow.uturn.up") }

            ChallengesView(manager: challenges)
                .tabItem { Label("Challenges", systemImage: "list.bullet.rectangle") }
        }
        .environmentObject(challenges)
        .onAppear {
            if bridge == nil {
                let b = ChallengeBridge(
                    get: { gameState },
                    set: { gameState = $0 }
                )
                bridge = b
                challenges.attach(hooks: b)
            }
        }
    }
}

private struct HomePlaceholderView: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 12) {
                Text("Your Home Screen").font(.title.bold())
                Text("Replace HomePlaceholderView() with your actual root view.")
                    .foregroundStyle(.secondary)
            }
            .padding()
            .navigationTitle("Home")
        }
    }
}

// Preview (optional)
#Preview { MainTabs() }
