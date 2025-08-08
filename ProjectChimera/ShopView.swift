import SwiftUI
import SwiftData

struct ShopView: View {
    @Bindable var user: User
    
    private let chests = ItemDatabase.shared.masterChestList
    
    @State private var showRewardPopup = false
    @State private var lastChestRewards: [LootReward] = []
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                
                // Header
                Text("Gold: \(user.gold) 🪙")
                    .font(.title2.bold())
                    .padding([.horizontal, .top])
                
                // Chests Section
                ForEach(chests) { chest in
                    ChestCardView(chest: chest, user: user, onOpen: { rewards in
                        lastChestRewards = rewards
                        showRewardPopup = true
                    })
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Treasure Trove")
        .sheet(isPresented: $showRewardPopup) {
            ChestRewardPopup(rewards: $lastChestRewards, isPresented: $showRewardPopup)
        }
    }
}

// MARK: - Chest Card View
struct ChestCardView: View {
    @Environment(\.modelContext) private var modelContext
    let chest: TreasureChest
    @Bindable var user: User
    var onOpen: ([LootReward]) -> Void
    
    private var canOpen: Bool {
        ShopManager.shared.canOpenChest(chest, user: user)
    }
    
    var body: some View {
        VStack(spacing: 15) {
            Image(systemName: chest.icon)
                .font(.system(size: 80))
                .foregroundColor(rarityColor(for: chest.rarity))
            
            Text(chest.name)
                .font(.title2).bold()
            
            Text(chest.description)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(action: {
                let rewards = ShopManager.shared.openChest(chest, user: user, context: modelContext)
                onOpen(rewards)
            }) {
                Text(buttonText)
            }
            .buttonStyle(JuicyButtonStyle())
            .tint(rarityColor(for: chest.rarity))
            .disabled(!canOpen)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Material.regular)
        .cornerRadius(20)
        .padding(.horizontal)
    }
    
    private var buttonText: String {
        if let keyID = chest.keyItemID {
            let keyName = ItemDatabase.shared.getItem(id: keyID)?.name ?? "Key"
            let keyCount = user.inventory?.first(where: { $0.itemID == keyID })?.quantity ?? 0
            return "Open (\(keyCount)x \(keyName))"
        } else {
            return "Buy & Open (\(chest.cost) G)"
        }
    }
    
    private func rarityColor(for rarity: Rarity) -> Color {
        switch rarity {
        case .common: return .brown
        case .rare: return .blue
        case .epic: return .purple
        case .legendary: return .orange
        }
    }
}

// MARK: - Reward Popup
struct ChestRewardPopup: View {
    @Binding var rewards: [LootReward]
    @Binding var isPresented: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Chest Opened!")
                .font(.largeTitle).bold()
            
            Text("You received:")
                .font(.headline)
            
            ForEach(rewards) { reward in
                RewardRowView(reward: reward)
            }
            
            Button("Awesome!") {
                isPresented = false
            }
            .buttonStyle(JuicyButtonStyle())
        }
        .padding()
    }
}
