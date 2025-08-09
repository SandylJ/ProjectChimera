
import Foundation
import SwiftData

final class GuildManager: ObservableObject {
    static let shared = GuildManager()
    private init() {}

    func initializeGuild(for user: User, context: ModelContext) {
        guard user.guild == nil else { return }
        let newGuild = Guild(owner: user)
        context.insert(newGuild)
        user.guild = newGuild
    }

    @discardableResult
    func hireGuildMember(role: GuildMember.Role, for user: User, context: ModelContext) -> Bool {
        let hireCost = 250
        guard user.gold >= hireCost else { return false }
        
        user.gold -= hireCost
        let newMember = GuildMember(name: "New \(role.rawValue)", role: role, owner: user)
        user.guildMembers?.append(newMember)
        return true
    }
    
    func upgradeGuildMember(member: GuildMember, user: User, context: ModelContext) {
        let cost = member.upgradeCost()
        guard user.gold >= cost else { return }
        
        user.gold -= cost
        member.level += 1
    }
    
    // MARK: - Expedition Management
    
    func launchExpedition(expeditionID: String, with memberIDs: [UUID], for user: User, context: ModelContext) {
        // Mark members as busy
        memberIDs.forEach { id in
            user.guildMembers?.first(where: { $0.id == id })?.isOnExpedition = true
        }
        
        // Create new expedition
        let newExpedition = ActiveExpedition(expeditionID: expeditionID, memberIDs: memberIDs, startTime: .now, owner: user)
        user.activeExpeditions?.append(newExpedition)
        
        // Add to context
        context.insert(newExpedition)
        
        do {
            try context.save()
        } catch {
            print("Failed to save expedition: \(error)")
        }
    }
    
    func completeExpedition(expedition: ActiveExpedition, for user: User, context: ModelContext) {
        guard let expeditionData = ItemDatabase.shared.getExpedition(id: expedition.expeditionID) else { 
            print("Failed to find expedition data for ID: \(expedition.expeditionID)")
            return 
        }
        
        // Give rewards
        user.totalXP += expeditionData.xpReward
        user.gold += calculateGoldReward(for: expeditionData, memberCount: expedition.memberIDs.count)
        
        // Add items to inventory
        for (itemID, quantity) in expeditionData.lootTable {
            addItemToInventory(itemID: itemID, quantity: quantity, for: user)
        }
        
        // Free up members
        expedition.memberIDs.forEach { id in
            user.guildMembers?.first(where: { $0.id == id })?.isOnExpedition = false
        }
        
        // Remove expedition
        user.activeExpeditions?.removeAll { $0.id == expedition.id }
        context.delete(expedition)
        
        do {
            try context.save()
        } catch {
            print("Failed to complete expedition: \(error)")
        }
    }
    
    func checkCompletedExpeditions(for user: User, context: ModelContext) {
        guard let expeditions = user.activeExpeditions, !expeditions.isEmpty else { return }
        
        let completedExpeditions = expeditions.filter { expedition in
            guard let expeditionData = ItemDatabase.shared.getExpedition(id: expedition.expeditionID) else { return false }
            let endTime = expedition.startTime.addingTimeInterval(expeditionData.duration)
            return endTime <= Date()
        }
        
        for expedition in completedExpeditions {
            completeExpedition(expedition: expedition, for: user, context: context)
        }
    }
    
    func cleanupInvalidExpeditions(for user: User, context: ModelContext) {
        guard let expeditions = user.activeExpeditions, !expeditions.isEmpty else { return }
        
        let invalidExpeditions = expeditions.filter { expedition in
            ItemDatabase.shared.getExpedition(id: expedition.expeditionID) == nil
        }
        
        for expedition in invalidExpeditions {
            // Free up members that were on this invalid expedition
            expedition.memberIDs.forEach { id in
                user.guildMembers?.first(where: { $0.id == id })?.isOnExpedition = false
            }
            
            // Remove expedition from user's list
            user.activeExpeditions?.removeAll { $0.id == expedition.id }
            
            // Delete from context
            context.delete(expedition)
        }
        
        if !invalidExpeditions.isEmpty {
            do {
                try context.save()
                print("Cleaned up \(invalidExpeditions.count) invalid expeditions")
            } catch {
                print("Failed to cleanup invalid expeditions: \(error)")
            }
        }
    }
    
    private func calculateGoldReward(for expedition: Expedition, memberCount: Int) -> Int {
        let baseGold = 50 + (expedition.xpReward / 10)
        let memberBonus = memberCount * 25
        return baseGold + memberBonus
    }
    
    private func addItemToInventory(itemID: String, quantity: Int, for user: User) {
        // Check if item already exists in inventory
        if let existingItem = user.inventory?.first(where: { $0.itemID == itemID }) {
            existingItem.quantity += quantity
        } else {
            // Create new inventory item
            let newItem = InventoryItem(itemID: itemID, quantity: quantity, owner: user)
            user.inventory?.append(newItem)
        }
    }

    // MARK: - Guild Progression

    func addGuildXP(_ amount: Int, for user: User) {
        guard let guild = user.guild else { return }
        guild.xp += amount
        checkGuildLevelUp(for: user)
    }

    private func checkGuildLevelUp(for user: User) {
        guard let guild = user.guild else { return }
        while guild.xp >= guild.xpToNextLevel {
            guild.xp -= guild.xpToNextLevel
            guild.level += 1
            // Unlock a random perk for now, can be more sophisticated later
            if let randomPerk = GuildPerk.allCases.randomElement() {
                guild.unlockedPerks.append(randomPerk)
            }
        }
    }

    // MARK: - Guild Bounties

    func generateDailyBounties(for user: User, context: ModelContext) {
        guard user.guildBounties?.isEmpty ?? true else { return }
        
        let bounties = [
            GuildBounty(title: "Defeat 10 Goblins", bountyDescription: "Hunt down goblins in the forest", requiredProgress: 10, guildXpReward: 100, guildSealReward: 10, owner: user, targetEnemyID: "enemy_goblin"),
            GuildBounty(title: "Craft 5 Potions", bountyDescription: "Brew healing potions", requiredProgress: 5, guildXpReward: 150, guildSealReward: 15, owner: user),
            GuildBounty(title: "Walk 5000 Steps", bountyDescription: "Stay active and explore", requiredProgress: 5000, guildXpReward: 75, guildSealReward: 8, owner: user)
        ]
        
        user.guildBounties = bounties
        
        for bounty in bounties {
            context.insert(bounty)
        }
    }
    
    func completeBounty(bounty: GuildBounty, for user: User) {
        user.gold += bounty.guildXpReward
        user.guildBounties?.removeAll { $0.id == bounty.id }
        
        // Add guild XP
        addGuildXP(bounty.guildXpReward, for: user)
    }
    
    func processHunts(for user: User, deltaTime: TimeInterval, context: ModelContext) {
        guard let activeHunts = user.activeHunts, !activeHunts.isEmpty else { return }
        
        for hunt in activeHunts {
            let killsPerSecond = calculateHuntKillsPerSecond(hunt: hunt, user: user)
            let newKills = Int(killsPerSecond * deltaTime)
            
            hunt.killsAccumulated += newKills
            hunt.lastUpdated = .now
            
            // Add gold to unclaimed pool
            if let enemy = hunt.enemy {
                user.unclaimedHuntGold += newKills * enemy.goldPerKill
            } else {
                // Default gold per kill if enemy data not available
                user.unclaimedHuntGold += newKills * 5
            }
            
            // Generate item rewards based on kills
            generateHuntItemRewards(kills: newKills, enemyID: hunt.enemyID, for: user)
        }
    }
    
    private func calculateHuntKillsPerSecond(hunt: ActiveHunt, user: User) -> Double {
        let totalDPS = hunt.memberIDs.compactMap { memberID in
            user.guildMembers?.first { $0.id == memberID }
        }.reduce(0.0) { total, member in
            total + member.combatDPS()
        }
        
        // Convert DPS to kills per second (simplified)
        return totalDPS / 10.0 // Assuming 10 DPS = 1 kill per second
    }
    
    private func generateHuntItemRewards(kills: Int, enemyID: String, for user: User) {
        // Base chance for items (higher for more kills)
        let baseChance = min(Double(kills) * 0.1, 0.8) // Max 80% chance
        
        // Different item pools for different enemies
        let itemPool = getItemPoolForEnemy(enemyID)
        
        for item in itemPool {
            let chance = baseChance * item.dropRate
            if Double.random(in: 0...1) < chance {
                let quantity = Int.random(in: item.minQuantity...item.maxQuantity)
                addUnclaimedHuntItem(itemID: item.itemID, quantity: quantity, for: user)
            }
        }
    }
    
    private func getItemPoolForEnemy(_ enemyID: String) -> [HuntItemDrop] {
        switch enemyID {
        case "enemy_goblin":
            return [
                HuntItemDrop(itemID: "material_essence", dropRate: 0.3, minQuantity: 1, maxQuantity: 3),
                HuntItemDrop(itemID: "item_potion_vigor", dropRate: 0.1, minQuantity: 1, maxQuantity: 1),
                HuntItemDrop(itemID: "material_sunwheat_grain", dropRate: 0.2, minQuantity: 2, maxQuantity: 5)
            ]
        case "enemy_zombie":
            return [
                HuntItemDrop(itemID: "material_dream_shard", dropRate: 0.25, minQuantity: 1, maxQuantity: 2),
                HuntItemDrop(itemID: "item_elixir_strength", dropRate: 0.08, minQuantity: 1, maxQuantity: 1),
                HuntItemDrop(itemID: "material_glowcap_spore", dropRate: 0.15, minQuantity: 1, maxQuantity: 3)
            ]
        case "enemy_spider":
            return [
                HuntItemDrop(itemID: "material_sunstone_shard", dropRate: 0.2, minQuantity: 1, maxQuantity: 2),
                HuntItemDrop(itemID: "item_scroll_fortune", dropRate: 0.05, minQuantity: 1, maxQuantity: 1),
                HuntItemDrop(itemID: "material_ironwood_bark", dropRate: 0.1, minQuantity: 1, maxQuantity: 2)
            ]
        case "enemy_skeleton":
            return [
                HuntItemDrop(itemID: "material_dream_shard", dropRate: 0.3, minQuantity: 2, maxQuantity: 4),
                HuntItemDrop(itemID: "equip_iron_helmet", dropRate: 0.03, minQuantity: 1, maxQuantity: 1),
                HuntItemDrop(itemID: "item_elixir_strength", dropRate: 0.12, minQuantity: 1, maxQuantity: 2)
            ]
        case "enemy_ghost":
            return [
                HuntItemDrop(itemID: "material_sunstone_shard", dropRate: 0.25, minQuantity: 2, maxQuantity: 4),
                HuntItemDrop(itemID: "item_scroll_fortune", dropRate: 0.08, minQuantity: 1, maxQuantity: 1),
                HuntItemDrop(itemID: "equip_scholars_robe", dropRate: 0.02, minQuantity: 1, maxQuantity: 1)
            ]
        case "enemy_dragon":
            return [
                HuntItemDrop(itemID: "material_sunstone_shard", dropRate: 0.4, minQuantity: 3, maxQuantity: 6),
                HuntItemDrop(itemID: "item_ancient_key", dropRate: 0.15, minQuantity: 1, maxQuantity: 2),
                HuntItemDrop(itemID: "equip_gauntlets_of_strength", dropRate: 0.05, minQuantity: 1, maxQuantity: 1),
                HuntItemDrop(itemID: "item_scroll_fortune", dropRate: 0.1, minQuantity: 1, maxQuantity: 2)
            ]
        default:
            return [
                HuntItemDrop(itemID: "material_essence", dropRate: 0.2, minQuantity: 1, maxQuantity: 2)
            ]
        }
    }
    
    private func addUnclaimedHuntItem(itemID: String, quantity: Int, for user: User) {
        // Check if item already exists in unclaimed items
        if let existingItem = user.unclaimedHuntItems.first(where: { $0.itemID == itemID }) {
            existingItem.quantity += quantity
        } else {
            // Create new unclaimed item
            let newItem = UnclaimedHuntItem(itemID: itemID, quantity: quantity, owner: user)
            user.unclaimedHuntItems.append(newItem)
        }
    }
    
    // MARK: - Scaling Costs
    
    func getHireCost(for role: GuildMember.Role, user: User) -> Int {
        let baseCost = 250
        let existingCount = (user.guildMembers ?? []).filter { $0.role == role }.count
        let scalingMultiplier = pow(1.5, Double(existingCount))
        return Int(Double(baseCost) * scalingMultiplier)
    }
    
    func getUpgradeCost(for member: GuildMember) -> Int {
        let baseCost = 100
        let levelScaling = pow(2.0, Double(member.level - 1))
        let roleMultiplier = getRoleUpgradeMultiplier(for: member.role)
        return Int(Double(baseCost) * levelScaling * roleMultiplier)
    }
    
    private func getRoleUpgradeMultiplier(for role: GuildMember.Role) -> Double {
        switch role {
        case .knight: return 1.0
        case .archer: return 1.2
        case .wizard: return 1.5
        case .rogue: return 1.3
        case .cleric: return 1.4
        default: return 1.0
        }
    }
}
