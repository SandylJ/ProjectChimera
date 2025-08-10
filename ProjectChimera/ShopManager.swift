import Foundation
import SwiftData

final class ShopManager: ObservableObject {
    static let shared = ShopManager()
    private init() {}

    /// Determines if a user can afford to open a specific chest.
    func canOpenChest(_ chest: TreasureChest, user: User) -> Bool {
        if let keyID = chest.keyItemID {
            // Check for key item
            return (user.inventory?.first(where: { $0.itemID == keyID })?.quantity ?? 0) > 0
        } else {
            // Check for currency
            let cost = effectiveChestCost(chest, user: user)
            return user.gold >= cost
        }
    }

    /// Opens a treasure chest, deducts the cost, and returns the generated loot.
    func openChest(_ chest: TreasureChest, user: User, context: ModelContext) -> [LootReward] {
        guard canOpenChest(chest, user: user) else { return [] }

        // 1. Deduct cost
        if let keyID = chest.keyItemID {
            if let keyItem = user.inventory?.first(where: { $0.itemID == keyID }) {
                keyItem.quantity -= 1
                if keyItem.quantity <= 0 {
                    context.delete(keyItem)
                }
            }
        } else {
            user.gold -= effectiveChestCost(chest, user: user)
        }

        // 2. Generate and grant loot
        let numberOfRewards = chest.rewardCount.randomElement() ?? 1
        let rewards = Array(chest.lootTable.shuffled().prefix(numberOfRewards))
        
        for reward in rewards {
            grantLoot(reward, to: user, context: context)
        }
        
        return rewards
    }
    
    // This is the same grantLoot function from QuestManager, centralized for reuse.
    // Unified with IdleGameManager.grantLoot semantics, but kept local to avoid cross-dependencies
    private func grantLoot(_ loot: LootReward, to user: User, context: ModelContext) {
        switch loot {
        case .currency(let amount):
            user.gold += amount
        case .item(let id, let quantity):
            if let inventoryItem = user.inventory?.first(where: { $0.itemID == id }) {
                inventoryItem.quantity += quantity
            } else {
                let newItem = InventoryItem(itemID: id, quantity: quantity, owner: user)
                user.inventory?.append(newItem)
            }
        case .experienceBurst(let skill, let amount):
            _ = GameLogicManager.shared.grantXP(to: skill, amount: amount, for: user)
        case .runes(let amount):
            user.runes += amount
        case .echoes(let amount):
            if let altar = user.altarOfWhispers {
                altar.echoes += amount
            }
        }
    }
    
    private func effectiveChestCost(_ chest: TreasureChest, user: User) -> Int {
        var cost = chest.cost
        if let level = user.altarCourtesies["shop_patron"], level > 0 {
            let discount = min(0.5, 0.05 * Double(level))
            cost = Int(Double(cost) * (1.0 - discount))
        }
        return max(0, cost)
    }
}
