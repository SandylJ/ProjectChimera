import Foundation
import SwiftData

final class SanctuaryManager: ObservableObject {
    static let shared = SanctuaryManager()
    private init() {}

    // MARK: - Garden Logic
    
    func plantItem(itemID: String, for user: User, context: ModelContext) {
        guard let itemToPlant = ItemDatabase.shared.getItem(id: itemID),
              let plantableType = itemToPlant.plantableType else { return }
        
        // Decrement item from inventory
        if let inventoryItem = user.inventory?.first(where: { $0.itemID == itemID }) {
            inventoryItem.quantity -= 1
            if inventoryItem.quantity <= 0 {
                context.delete(inventoryItem)
            }
        } else { return } // Can't plant if they don't have it
        
        // Add to the correct planted list
        var actualPlantedAt = Date()
        for (effect, _) in user.activeBuffs {
            if case .plantGrowthSpeed(let multiplier) = effect {
                // Reduce the effective grow time by adjusting the plantedAt date forward
                actualPlantedAt = actualPlantedAt.addingTimeInterval(itemToPlant.growTime! * multiplier * -1)
            }
        }

        switch plantableType {
        case .habitSeed:
            let newPlantedSeed = PlantedHabitSeed(seedID: itemID, plantedAt: actualPlantedAt, owner: user)
            user.plantedHabitSeeds?.append(newPlantedSeed)
            user.totalSeedsPlantedByGuild += 1
        case .crop:
            let newPlantedCrop = PlantedCrop(cropID: itemID, plantedAt: actualPlantedAt, owner: user)
            user.plantedCrops?.append(newPlantedCrop)
            user.totalCropsPlantedByGuild += 1
        case .treeSapling:
            let newPlantedTree = PlantedTree(treeID: itemID, plantedAt: actualPlantedAt, owner: user)
            user.plantedTrees?.append(newPlantedTree)
            user.totalTreesPlantedByGuild += 1
        }
    }

    func harvest(plantedItem: any PersistentModel, for user: User, context: ModelContext) {
        var reward: Item.HarvestReward?
        
        // Determine the reward based on the type of item harvested
        if let seed = plantedItem as? PlantedHabitSeed {
            reward = seed.seed?.harvestReward
            user.totalSeedsHarvestedByGuild += 1
        } else if let crop = plantedItem as? PlantedCrop {
            reward = crop.crop?.harvestReward
            user.totalCropsHarvestedByGuild += 1
        } else if let tree = plantedItem as? PlantedTree {
            reward = tree.tree?.harvestReward
            user.totalTreesHarvestedByGuild += 1
        }
        
        // Grant the reward
        if let reward = reward {
            grantReward(reward, to: user, context: context)
        } else {
            user.gold += 10 // Fallback
        }
        
        // Delete the harvested item
        context.delete(plantedItem)
    }
    
    private func grantReward(_ reward: Item.HarvestReward, to user: User, context: ModelContext) {
        switch reward {
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
        }
    }

    
}
