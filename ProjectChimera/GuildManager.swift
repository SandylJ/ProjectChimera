
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
        // Award guild XP and seals
        addGuildXP(bounty.guildXpReward, for: user)
        user.guildSeals += bounty.guildSealReward
        
        // Optional: small gold bonus equal to 10% of XP
        user.gold += max(0, bounty.guildXpReward / 10)
        
        // Mark inactive and remove from list
        bounty.isActive = false
        user.guildBounties?.removeAll { $0.id == bounty.id }
    }
    
    // MARK: - Passive Hunts Processing (toned-down loot + guild XP + enemy modifiers)
    func processHunts(for user: User, deltaTime: TimeInterval, context: ModelContext) {
        guard let activeHunts = user.activeHunts, !activeHunts.isEmpty else { return }
        
        for hunt in activeHunts {
            let killsPerSecond = calculateHuntKillsPerSecond(hunt: hunt, user: user)
            let newKills = Int(killsPerSecond * deltaTime)
            
            guard newKills > 0 else { continue }
            
            hunt.killsAccumulated += newKills
            hunt.lastUpdated = .now
            
            // Track per-enemy kill tally
            var tally = user.huntKillTally
            tally[hunt.enemyID, default: 0] += newKills
            user.huntKillTally = tally
            
            // Add gold to unclaimed pool (reduced by >50%)
            let perKillGold = adjustedGoldPerKill(for: hunt.enemyID)
            user.unclaimedHuntGold += newKills * perKillGold
            
            // Generate item rewards (reduced rates and quantities)
            generateHuntItemRewards(kills: newKills, enemyID: hunt.enemyID, for: user)
            
            // Add slow Guild XP progression
            let xpGain = (newKills / 25) + Int(Double(newKills) * xpPerKill(for: hunt.enemyID))
            if xpGain > 0 { addGuildXP(xpGain, for: user) }
        }
    }
    
    // Exposed so UI can reflect the real-time KPS used by the engine
    func calculateHuntKillsPerSecond(hunt: ActiveHunt, user: User) -> Double {
        let members: [GuildMember] = hunt.memberIDs.compactMap { memberID in
            user.guildMembers?.first { $0.id == memberID }
        }
        guard !members.isEmpty else { return 0.0 }
        
        let roleMultipliers = getEnemyRoleMultipliers(hunt.enemyID)
        
        // Cleric provides team-wide DPS multiplier (10% per level)
        let clericLevelSum = members.filter { $0.role == .cleric }.reduce(0) { $0 + $1.level }
        let clericBuff = 1.0 + 0.10 * Double(clericLevelSum)
        
        let baseTeamDPS = members.reduce(0.0) { total, member in
            let memberBase = member.combatDPS()
            let mult = roleMultipliers[member.role] ?? 1.0
            return total + memberBase * mult
        }
        
        let effectiveDPS = baseTeamDPS * clericBuff
        
        // Convert DPS to kills per second (simplified)
        return effectiveDPS / 10.0
    }
    
    // Role multipliers per enemy to model strengths/weaknesses
    func getEnemyRoleMultipliers(_ enemyID: String) -> [GuildMember.Role: Double] {
        switch enemyID {
        case "enemy_spider":
            // Agile foes vulnerable to poisons and precise strikes
            return [.rogue: 1.3, .wizard: 1.1, .archer: 1.0, .knight: 0.85, .cleric: 1.0]
        case "enemy_wolf":
            // Pack beasts; archers are effective at range
            return [.archer: 1.2, .knight: 1.0, .rogue: 1.0, .wizard: 0.9, .cleric: 1.0]
        case "enemy_goblin":
            // Squishy tricksters; disciplined fronts and ranged focus help
            return [.knight: 1.25, .archer: 1.15, .rogue: 1.0, .wizard: 1.0, .cleric: 1.0]
        case "enemy_skeleton":
            // Bones are weak to blunt force; arrows less effective
            return [.knight: 1.3, .wizard: 1.15, .archer: 0.75, .rogue: 0.9, .cleric: 1.0]
        case "enemy_zombie":
            // Undead resist blades, weak to magic
            return [.wizard: 1.6, .knight: 1.0, .archer: 0.9, .rogue: 0.5, .cleric: 1.05]
        case "enemy_ghost":
            // Ethereal; holy and arcane excel, physical falters
            return [.cleric: 1.8, .wizard: 1.4, .knight: 0.7, .archer: 0.7, .rogue: 0.6]
        case "enemy_dragon":
            // Ancient might; favors disciplined ranged and arcane
            return [.wizard: 1.3, .archer: 1.2, .knight: 1.0, .rogue: 0.8, .cleric: 1.0]
        default:
            return [:]
        }
    }
    
    // Gold per kill after global passive reduction (>50% reduction)
    func adjustedGoldPerKill(for enemyID: String) -> Int {
        let base = GameData.shared.getEnemy(id: enemyID)?.goldPerKill ?? 5
        let adjusted = Int(round(Double(base) * 0.4))
        return max(1, adjusted)
    }
    
    // Slow guild XP per kill varies slightly by enemy difficulty
    private func xpPerKill(for enemyID: String) -> Double {
        switch enemyID {
        case "enemy_spider": return 0.03
        case "enemy_wolf": return 0.035
        case "enemy_goblin": return 0.04
        case "enemy_skeleton": return 0.05
        case "enemy_zombie": return 0.06
        case "enemy_ghost": return 0.08
        case "enemy_dragon": return 0.2
        default: return 0.04
        }
    }
    
    private func generateHuntItemRewards(kills: Int, enemyID: String, for user: User) {
        // Base chance for items (toned down): lower slope and cap
        let baseChance = min(Double(kills) * 0.04, 0.35)
        
        // Different item pools for different enemies
        let itemPool = getItemPoolForEnemy(enemyID)
        
        for item in itemPool {
            let chance = baseChance * item.dropRate
            if Double.random(in: 0...1) < chance {
                let rawQuantity = Int.random(in: item.minQuantity...item.maxQuantity)
                // Reduce quantity by ~50%, at least 1
                let quantity = max(1, Int(Double(rawQuantity) * 0.5))
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

    // MARK: - Automation Processing (NEW)
    func processAutomations(for user: User, context: ModelContext) {
        let now = Date()
        let last = user.lastAutomationRun ?? now
        let deltaTime = now.timeIntervalSince(last)
        guard deltaTime > 0 else { return }
        user.lastAutomationRun = now

        let settings = user.guildAutomation
        if settings.autoHarvestGarden { autoHarvestGarden(for: user, context: context) }
        if settings.autoPlantHabitSeeds { autoPlantHabitSeeds(for: user, context: context) }
        if settings.foragerGatherForAltar { processForagerGathering(for: user, deltaTime: deltaTime, context: context) }
    }

    private func autoHarvestGarden(for user: User, context: ModelContext) {
        let now = Date()
        // Habit Seeds
        for planted in (user.plantedHabitSeeds ?? []) {
            if let seed = planted.seed, let growTime = seed.growTime, planted.plantedAt.addingTimeInterval(growTime) <= now {
                SanctuaryManager.shared.harvest(plantedItem: planted, for: user, context: context)
            }
        }
        // Crops
        for planted in (user.plantedCrops ?? []) {
            if let crop = planted.crop, let growTime = crop.growTime, planted.plantedAt.addingTimeInterval(growTime) <= now {
                SanctuaryManager.shared.harvest(plantedItem: planted, for: user, context: context)
            }
        }
        // Trees
        for planted in (user.plantedTrees ?? []) {
            if let tree = planted.tree, let growTime = tree.growTime, planted.plantedAt.addingTimeInterval(growTime) <= now {
                SanctuaryManager.shared.harvest(plantedItem: planted, for: user, context: context)
            }
        }
    }

    private func autoPlantHabitSeeds(for user: User, context: ModelContext) {
        // Respect a max of 6 plots like the main view
        let maxPlots = user.guildAutomation.gardenerMaintainPlots
        let currentCount = (user.plantedHabitSeeds ?? []).count
        guard currentCount < maxPlots else { return }

        // Determine which seed to plant
        let preferredID = user.guildAutomation.preferredHabitSeedID
        var seedInventoryItems: [InventoryItem] = (user.inventory ?? []).filter { inv in
            guard let item = ItemDatabase.shared.getItem(id: inv.itemID) else { return false }
            return item.plantableType == .habitSeed && inv.quantity > 0
        }
        guard !seedInventoryItems.isEmpty else { return }

        // If a preferred seed is set and available, prioritize it
        if let preferredID = preferredID, let idx = seedInventoryItems.firstIndex(where: { $0.itemID == preferredID }) {
            let preferred = seedInventoryItems.remove(at: idx)
            seedInventoryItems.insert(preferred, at: 0)
        }

        // Plant until reaching the target plots or running out of seeds
        var plotsToFill = maxPlots - currentCount
        for inv in seedInventoryItems {
            guard plotsToFill > 0 else { break }
            let toPlant = min(inv.quantity, plotsToFill)
            for _ in 0..<toPlant {
                SanctuaryManager.shared.plantItem(itemID: inv.itemID, for: user, context: context)
                plotsToFill -= 1
                if plotsToFill == 0 { break }
            }
        }
    }

    private func processForagerGathering(for user: User, deltaTime: TimeInterval, context: ModelContext) {
        // For each Forager, accumulate progress toward finding an item
        let foragers = (user.guildMembers ?? []).filter { $0.role == .forager }
        guard !foragers.isEmpty else { return }

        let itemsPerSecond = foragers.reduce(0.0) { partial, member in
            let interval = max(60.0, 3600.0 / Double(max(1, member.level))) // clamp to avoid too-fast at low levels
            return partial + (1.0 / interval)
        }

        user.automationProgressForager += itemsPerSecond * deltaTime
        let itemsToAward = Int(user.automationProgressForager)
        user.automationProgressForager -= Double(itemsToAward)
        guard itemsToAward > 0 else { return }

        for _ in 0..<itemsToAward {
            if let rewardID = pickForagerRewardItemID() {
                addItemToInventory(itemID: rewardID, quantity: 1, for: user)
                user.totalItemsFoundByGuild += 1
            } else {
                user.gold += 5
            }
        }
    }

    private func pickForagerRewardItemID() -> String? {
        // Prefer materials that exist in DB; fall back to a plantable seed
        let candidateIDs = [
            "material_essence",
            "material_joyful_ember",
            "material_sunstone_shard",
            "material_dream_shard",
            "material_glowcap_spore",
            "material_ironwood_bark"
        ]
        let valid = candidateIDs.filter { ItemDatabase.shared.getItem(id: $0) != nil }
        if let id = valid.randomElement() { return id }
        // fallback: any plantable
        if let anySeed = ItemDatabase.shared.getAllPlantables().first?.id { return anySeed }
        return nil
    }
}
