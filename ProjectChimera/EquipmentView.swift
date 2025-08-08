import SwiftUI
import SwiftData

struct EquipmentView: View {
    @Bindable var user: User

    var body: some View {
        VStack {
            Text("Equipment")
                .font(.largeTitle)
                .padding()

            // Equipped Items
            VStack(spacing: 15) {
                ForEach(EquipmentSlot.allCases, id: \.self) { slot in
                    EquipmentSlotRow(slot: slot, itemID: user.equippedItems[slot], onUnequip: {
                        EquipmentManager.shared.unequipItem(slot: slot, for: user)
                    })
                }
            }
            .padding()

            // Total Bonuses
            VStack {
                Text("Total Bonuses")
                    .font(.headline)
                ForEach(EquipmentManager.shared.getBonuses(for: user), id: \.self) { bonus in
                    Text("+\(bonus.value) \(bonus.stat.rawValue.capitalized)")
                }
            }
            .padding()

            // Inventory
            List {
                Section(header: Text("Inventory")) {
                    ForEach(user.inventory?.filter { inventoryItem in
                        if let item = ItemDatabase.shared.getItem(id: inventoryItem.itemID) {
                            return item.itemType == .equippable
                        } else {
                            return false
                        }
                    } ?? []) { inventoryItem in
                        Button(action: {
                            EquipmentManager.shared.equipItem(itemID: inventoryItem.itemID, for: user)
                        }) {
                            Text(ItemDatabase.shared.getItem(id: inventoryItem.itemID)?.name ?? "Unknown Item")
                        }
                    }
                }
            }
        }
    }
}

struct EquipmentSlotRow: View {
    let slot: EquipmentSlot
    let itemID: String?
    let onUnequip: () -> Void

    var body: some View {
        HStack {
            Text(slot.rawValue.capitalized)
                .font(.headline)
            Spacer()
            if let itemID = itemID, let item = ItemDatabase.shared.getItem(id: itemID) {
                VStack(alignment: .trailing) {
                    Text(item.name)
                        .font(.body)
                    if let bonuses = item.bonuses {
                        ForEach(bonuses, id: \.self) { bonus in
                            Text("+\(bonus.value) \(bonus.stat.rawValue.capitalized)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                Button(action: onUnequip) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                }
            } else {
                Text("Empty")
                    .foregroundColor(.secondary)
            }
        }
    }
}