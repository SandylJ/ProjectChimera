
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
    
    func launchExpedition(expeditionID: String, with memberIDs: [UUID], for user: User, context: ModelContext) {
        memberIDs.forEach { id in
            user.guildMembers?.first(where: { $0.id == id })?.isOnExpedition = true
        }
        
        let newExpedition = ActiveExpedition(expeditionID: expeditionID, memberIDs: memberIDs, startTime: .now, owner: user)
        user.activeExpeditions?.append(newExpedition)
    }
    
    func checkCompletedExpeditions(for user: User, context: ModelContext) {
        guard let expeditions = user.activeExpeditions, !expeditions.isEmpty else { return }
        
        let completedExpeditions = expeditions.filter { $0.endTime <= .now }
        
        for expedition in completedExpeditions {
            user.totalXP += expedition.expedition?.xpReward ?? 0
            user.gold += 100
            
            expedition.memberIDs.forEach { id in
                user.guildMembers?.first(where: { $0.id == id })?.isOnExpedition = false
            }
            
            context.delete(expedition)
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
        // For simplicity, generate 3 random bounties daily
        // In a real game, you'd have a master list of bounty templates
        guard user.guildBounties?.isEmpty ?? true else { return }

        // One combat bounty (goblins)
        let goblinBounty = GuildBounty(
            title: "Defeat 5 Goblins",
            bountyDescription: "Slay the pesky goblins infesting the forest.",
            requiredProgress: 5,
            guildXpReward: 100,
            guildSealReward: 10,
            owner: user,
            targetEnemyID: "enemy_goblin"
        )
        context.insert(goblinBounty)
        user.guildBounties?.append(goblinBounty)

        // Two non-combat bounties (placeholder reuse of previous style)
        for _ in 0..<2 {
            let newBounty = GuildBounty(
                title: "Gather Supplies",
                bountyDescription: "Assist the guild with miscellaneous tasks.",
                requiredProgress: 3,
                guildXpReward: 60,
                guildSealReward: 6,
                owner: user
            )
            context.insert(newBounty)
            user.guildBounties?.append(newBounty)
        }
    }

    func completeBounty(bounty: GuildBounty, for user: User) {
        guard bounty.currentProgress >= bounty.requiredProgress else { return }
        bounty.isActive = false // Mark as completed
        addGuildXP(bounty.guildXpReward, for: user)
        user.guildSeals += bounty.guildSealReward
    }

    // MARK: - Blacksmith Logic

    func blacksmithCraftMaterial(for user: User, context: ModelContext) {
        // Example: Blacksmith passively crafts 'material_iron_ore'
        // This would be more complex with different materials and success rates
        if let ironOre = user.inventory?.first(where: { $0.itemID == "material_iron_ore" }) {
            ironOre.quantity += 1
        } else {
            let newItem = InventoryItem(itemID: "material_iron_ore", quantity: 1, owner: user)
            user.inventory?.append(newItem)
        }
    }

    func blacksmithEnhanceEquipment(item: InventoryItem, for user: User) {
        // Example: Blacksmith enhances an equipped item
        // This would involve modifying the item's bonuses directly or creating a new item
        // For simplicity, let's just say it increases a random stat on the item
        guard let equippedItem = ItemDatabase.shared.getItem(id: item.itemID), equippedItem.itemType == .equippable else { return }

        // This is a placeholder. Actual implementation would be more complex.
        print("Blacksmith enhanced \(equippedItem.name)!")
    }

    // MARK: - Hunts (Passive Combat)

    func startHunt(enemyID: String, with memberIDs: [UUID], for user: User, context: ModelContext) {
        guard !memberIDs.isEmpty else { return }
        let hunt = ActiveHunt(enemyID: enemyID, memberIDs: memberIDs, owner: user)
        context.insert(hunt)
        user.activeHunts?.append(hunt)
    }

    func stopHunt(_ hunt: ActiveHunt, for user: User, context: ModelContext) {
        if let idx = user.activeHunts?.firstIndex(where: { $0.id == hunt.id }) {
            let toDelete = user.activeHunts!.remove(at: idx)
            context.delete(toDelete)
        }
    }

    func totalPartyDPS(memberIDs: [UUID], on user: User) -> Double {
        let members = (user.guildMembers ?? []).filter { memberIDs.contains($0.id) }
        let baseDPS = members.reduce(0.0) { $0 + $1.combatDPS() }
        let clericLevels = members.filter { $0.role == .cleric }.reduce(0) { $0 + $1.level }
        let clericMultiplier = 1.0 + (Double(clericLevels) * 0.10)
        return baseDPS * clericMultiplier
    }

    func processHunts(for user: User, deltaTime: TimeInterval, context: ModelContext) {
        guard let hunts = user.activeHunts, !hunts.isEmpty else { return }
        let goldBoostMultiplier: Double = {
            var m = 1.0
            for (effect, expiry) in user.activeBuffs where Date() < expiry {
                if case .goldBoost(let multi) = effect { m *= (1.0 + multi) }
            }
            return m
        }()

        for hunt in hunts {
            // Keep hunt party in sync with current combatants so newly hired mercs matter immediately
            let currentCombatantIDs = (user.guildMembers ?? []).filter { $0.isCombatant }.map { $0.id }
            if hunt.memberIDs != currentCombatantIDs { hunt.memberIDs = currentCombatantIDs }
            
            guard let enemy = hunt.enemy else { continue }
            let dps = totalPartyDPS(memberIDs: hunt.memberIDs, on: user)
            guard dps > 0 else { continue }
            let damage = dps * deltaTime
            let kills = Int(floor(damage / max(1.0, enemy.health)))
            if kills > 0 {
                hunt.killsAccumulated += kills
                
                // Mercenary-based gold multiplier: modest, scales with party size and role diversity, with a soft cap
                let members = (user.guildMembers ?? []).filter { hunt.memberIDs.contains($0.id) }
                let partyCount = members.count
                let uniqueRoles = Set(members.map { $0.role }).count
                let mercGoldMultiplier = min(1.0 + 0.04 * Double(partyCount) + 0.03 * Double(uniqueRoles), 1.75)
                
                let goldEarned = Int(Double(enemy.goldPerKill * kills) * goldBoostMultiplier * mercGoldMultiplier)
                user.unclaimedHuntGold += goldEarned
                var tally = user.huntKillTally
                tally[enemy.id, default: 0] += kills
                user.huntKillTally = tally
                // Progress any matching combat bounties
                if let bounties = user.guildBounties {
                    for bounty in bounties where bounty.isActive {
                        if let target = bounty.targetEnemyID, target == enemy.id {
                            bounty.currentProgress = min(bounty.requiredProgress, bounty.currentProgress + kills)
                            // Auto-complete combat bounties when requirements are met
                            if bounty.currentProgress >= bounty.requiredProgress {
                                completeBounty(bounty: bounty, for: user)
                            }
                        }
                    }
                }
            }
            hunt.lastUpdated = Date()
        }
    }

    func processOfflineHunts(for user: User, context: ModelContext) {
        guard let hunts = user.activeHunts, !hunts.isEmpty else { return }
        let now = Date()
        for hunt in hunts {
            let delta = now.timeIntervalSince(hunt.lastUpdated)
            guard delta > 1 else { continue }
            let before = hunt.killsAccumulated
            processHunts(for: user, deltaTime: delta, context: context)
            // Ensure we do not reapply delta repeatedly in a loop; lastUpdated is set in processHunts.
            let _ = before
        }
    }

    // MARK: - Claim Hunt Rewards
    func claimHuntRewards(for user: User) {
        guard user.unclaimedHuntGold > 0 else { return }
        user.gold += user.unclaimedHuntGold
        user.unclaimedHuntGold = 0
    }
}
