import SwiftUI

struct ChallengesView: View {
    @ObservedObject var manager: DailyChallengeManager

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Daily & Weekly").font(.largeTitle.bold())
                Spacer()
                Text("Streak: \(manager.streak)")
            }
            List {
                ForEach(manager.todays) { c in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(title(for: c.kind)).font(.headline)
                        ProgressView(value: Double(c.progress), total: Double(c.target))
                        Text("\(c.progress)/\(c.target)")
                        Text("Reward: \(rewardString(c.reward))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Button("Redeem Completed") { manager.redeemCompleted() }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)
        }
        .padding(.top)
    }

    private func title(for kind: ChallengeKind) -> String {
        switch kind {
        case .tasksCompleted: return "Complete Tasks"
        case .steps: return "Walk Steps"
        case .crafting: return "Craft Items"
        case .questBoss: return "Defeat a Boss"
        }
    }

    private func rewardString(_ r: RewardBundle) -> String {
        var parts: [String] = []
        if r.gold > 0 { parts.append("\(r.gold) gold") }
        parts.append(contentsOf: r.items.map { "\($0.value)× \($0.key)" })
        return parts.joined(separator: ", ")
    }
}
