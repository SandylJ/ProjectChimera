import Foundation

struct GameState: Codable, Hashable, PrestigeGameState {
    // Meta / Prestige signals
    var totalPowerEarned: Int = 0

    // Simple economy mirror (decouple from User for now)
    var gold: Int = 0
    var inventory: [String: Int] = [:]

    mutating func softResetPreservingMeta() {
        gold = 0
        inventory.removeAll()
        // keep totalPowerEarned (meta)
    }

    mutating func addGold(_ amount: Int) {
        gold = max(0, gold + amount)
    }

    mutating func addItem(id: String, quantity: Int) {
        guard quantity != 0 else { return }
        inventory[id, default: 0] += quantity
        if inventory[id]! <= 0 { inventory.removeValue(forKey: id) }
    }
}
