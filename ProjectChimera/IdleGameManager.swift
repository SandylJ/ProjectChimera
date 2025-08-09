
import Foundation
import SwiftData

// MARK: - Altar of Whispers Manager

final class IdleGameManager: ObservableObject {
    static let shared = IdleGameManager()
    private init() {}

    func initializeAltar(for user: User, context: ModelContext) {
        guard user.altarOfWhispers == nil else { return }
        let newAltar = AltarOfWhispers(owner: user)
        context.insert(newAltar)
        user.altarOfWhispers = newAltar
    }

    func processOfflineProgress(for user: User) {
        guard let altar = user.altarOfWhispers else { return }
        
        let now = Date()
        let timeOffline = now.timeIntervalSince(altar.lastUpdated)
        
        // Only process if offline for more than a minute
        guard timeOffline > 60 else { return }
        
        let echoesEarned = totalEchoesPerSecond(for: user) * timeOffline
        altar.echoes += echoesEarned

        let goldEarned = altar.goldPerSecond * timeOffline
        user.gold += Int(goldEarned)

        let runesEarned = altar.runesPerSecond * timeOffline
        user.runes += Int(runesEarned)
        
        altar.lastUpdated = now
    }
    
    func upgradeAltar(for user: User) {
        guard let altar = user.altarOfWhispers else { return }
        
        let cost = altar.upgradeCost
        guard altar.echoes >= cost else { return }
        
        altar.echoes -= cost
        altar.level += 1
    }

    func upgradeEchoMultiplier(for user: User) {
        guard let altar = user.altarOfWhispers else { return }
        
        let cost = altar.echoMultiplierUpgradeCost
        guard altar.echoes >= cost else { return }
        
        altar.echoes -= cost
        altar.echoMultiplierLevel += 1
    }

    func upgradeRuneGeneration(for user: User) {
        guard let altar = user.altarOfWhispers else { return }
        
        let cost = altar.runeGenerationUpgradeCost
        guard altar.echoes >= cost else { return }
        
        altar.echoes -= cost
        altar.runeGenerationLevel += 1
    }

    func upgradeGoldGeneration(for user: User) {
        guard let altar = user.altarOfWhispers else { return }
        
        let cost = altar.goldGenerationUpgradeCost
        guard altar.echoes >= cost else { return }
        
        altar.echoes -= cost
        altar.goldGenerationLevel += 1
    }

    // MARK: - Integration Logic

    func totalEchoesPerSecond(for user: User) -> Double {
        guard let altar = user.altarOfWhispers else { return 0.0 }

        // Only apply Seer bonus if assigned to attune altar via automation settings
        let seerBonusActive = user.guildAutomation.seerAttuneAltar
        let seerBonus = seerBonusActive ? (user.guildMembers?
            .filter { $0.role == .seer }
            .reduce(0.0) { $0 + (Double($1.level) * 0.1) } ?? 0.0) : 0.0

        return altar.echoesPerSecond * (1.0 + seerBonus)
    }

    func grantLoot(_ loot: LootReward, to user: User, context: ModelContext) {
        switch loot {
        case .currency(let amount):
            user.gold += amount
        case .item(let id, let quantity):
            if let invItem = user.inventory?.first(where: { $0.itemID == id }) {
                invItem.quantity += quantity
            } else {
                user.inventory?.append(InventoryItem(itemID: id, quantity: quantity, owner: user))
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

    // MARK: - Offline Hunts
    func processOfflineHunts(for user: User, context: ModelContext) {
        GuildManager.shared.processHunts(for: user, deltaTime: 3600, context: context) // Process 1 hour of offline time
    }
}
