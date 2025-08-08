import Foundation
import SwiftData

/// A manager responsible for updating and hatching eggs. Eggs accumulate
/// HealthKit steps over time. Once an egg’s `currentSteps` meet the
/// requirement determined by its `eggType`, the egg can be hatched to
/// award the player with loot. This manager provides helper methods to
/// increment step counts and handle hatching.
final class EggManager {
    static let shared = EggManager()
    private init() {}

    /// Adds the given number of steps to all of a user’s eggs. If any egg
    /// becomes ready to hatch as a result, it will not hatch automatically;
    /// call `hatchEgg(_:for:context:)` separately to redeem the rewards. This
    /// separation allows the UI to prompt users when an egg is ready.
    func updateEggProgress(for user: User, steps: Int) {
        guard let eggs = user.eggs else { return }
        for egg in eggs where !egg.hatched {
            egg.currentSteps += steps
        }
    }

    /// Hatches an egg and grants its rewards to the user if it is ready.
    /// - Parameters:
    ///   - egg: The egg to hatch.
    ///   - user: The owner of the egg.
    ///   - context: The database context used to delete the egg and
    ///     persist changes.
    func hatchEgg(_ egg: HatchableEgg, for user: User, context: ModelContext) {
        guard egg.isReadyToHatch, !egg.hatched else { return }
        // Mark as hatched to prevent double hatching
        egg.hatched = true
        // Grant each reward
        for reward in egg.rewards {
            switch reward {
            case .currency(let amount):
                user.gold += amount
            case .item(let id, let quantity):
                if let existing = user.inventory?.first(where: { $0.itemID == id }) {
                    existing.quantity += quantity
                } else {
                    let newItem = InventoryItem(itemID: id, quantity: quantity, owner: user)
                    user.inventory?.append(newItem)
                }
            case .experienceBurst(let skill, let amount):
                _ = GameLogicManager.shared.grantXP(to: skill, amount: amount, for: user)
            case .runes(let amount):
                user.runes += amount
            case .echoes(let amount):
                user.altarOfWhispers?.echoes += amount
            }
        }
        // Remove the egg from the user’s list
        if let index = user.eggs?.firstIndex(where: { $0.id == egg.id }) {
            user.eggs?.remove(at: index)
        }
        context.delete(egg)
    }
}