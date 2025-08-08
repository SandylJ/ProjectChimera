
import Foundation
import SwiftData

final class EquipmentManager: ObservableObject {
    static let shared = EquipmentManager()
    private init() {}

    func equipItem(itemID: String, for user: User) {
        guard let item = ItemDatabase.shared.getItem(id: itemID), let slot = item.slot else { return }

        // Unequip any existing item in the same slot
        if user.equippedItems[slot] != nil {
            unequipItem(slot: slot, for: user)
        }

        user.equippedItems[slot] = itemID
    }

    func unequipItem(slot: EquipmentSlot, for user: User) {
        user.equippedItems.removeValue(forKey: slot)
    }

    func getBonuses(for user: User) -> [EquipmentBonus] {
        var bonuses: [EquipmentBonus] = []
        for (_, itemID) in user.equippedItems {
            if let item = ItemDatabase.shared.getItem(id: itemID), let itemBonuses = item.bonuses {
                bonuses.append(contentsOf: itemBonuses)
            }
        }
        return bonuses
    }
}
