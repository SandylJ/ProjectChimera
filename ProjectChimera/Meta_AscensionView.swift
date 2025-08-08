import SwiftUI

struct AscensionView<S: PrestigeGameState>: View {
    @ObservedObject var ascension: AscensionManager
    @Binding var state: S

    var body: some View {
        VStack(spacing: 16) {
            Text("Ascension").font(.largeTitle.bold())
            Text("Prestige Currency: \(ascension.prestigeCurrency)")
            Text("Total Power: \(state.totalPowerEarned)")
            if ascension.canAscend(currentTotalPower: state.totalPowerEarned) {
                Button("Ascend (+\(ascension.projectedGain(for: state.totalPowerEarned)))") {
                    ascension.ascend(state: &state)
                }
                .buttonStyle(.borderedProminent)
            } else {
                Text("Keep pushing to ascend!")
            }
            Divider()
            Text("Perks").font(.title2.bold())
            List(ascension.availablePerks) { perk in
                HStack {
                    VStack(alignment: .leading) {
                        Text(perk.name).font(.headline)
                        Text(perk.desc).font(.subheadline)
                    }
                    Spacer()
                    if ascension.ownedPerkIDs.contains(perk.id) {
                        Text("Owned").foregroundColor(.secondary)
                    } else {
                        Button("Buy \(perk.cost)") {
                            _ = ascension.purchase(perk: perk)
                        }
                    }
                }
            }
        }
        .padding()
    }
}
