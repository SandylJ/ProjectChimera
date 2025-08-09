import Foundation
import SwiftData
import AVFoundation
import CoreHaptics
import SwiftUI

// MARK: - Crafting Manager (NEW)

final class CraftingManager {
    static let shared = CraftingManager()
    private init() {}

    /// Checks if a user has the required materials and gold to craft a recipe.
    func canCraft(_ recipe: Recipe, user: User) -> Bool {
        guard user.gold >= recipe.requiredGold else { return false }
        
        for (itemID, requiredQuantity) in recipe.requiredMaterials {
            let userQuantity = user.inventory?.first(where: { $0.itemID == itemID })?.quantity ?? 0
            if userQuantity < requiredQuantity {
                return false
            }
        }
        return true
    }

    /// Crafts an item, consuming materials and gold, and adding the new item to the user's inventory.
    func craftItem(_ recipe: Recipe, user: User, context: ModelContext) {
        guard canCraft(recipe, user: user) else { return }

        // 1. Deduct gold
        user.gold -= recipe.requiredGold

        // 2. Deduct materials
        for (itemID, requiredQuantity) in recipe.requiredMaterials {
            if let inventoryItem = user.inventory?.first(where: { $0.itemID == itemID }) {
                inventoryItem.quantity -= requiredQuantity
                if inventoryItem.quantity <= 0 {
                    context.delete(inventoryItem)
                }
            }
        }

        // 3. Add crafted item
        if let inventoryItem = user.inventory?.first(where: { $0.itemID == recipe.craftedItemID }) {
            inventoryItem.quantity += 1
        } else {
            let newItem = InventoryItem(itemID: recipe.craftedItemID, quantity: 1, owner: user)
            user.inventory?.append(newItem)
        }
    }
}


// MARK: - Spellbook Manager

final class SpellbookManager {
    static let shared = SpellbookManager()
    private init() {}
    func unlockNewSpells(for user: User) {
        let masterList = ItemDatabase.shared.masterSpellList
        for spell in masterList {
            if user.level >= spell.requiredLevel && !user.unlockedSpellIDs.contains(spell.id) {
                user.unlockedSpellIDs.append(spell.id)
            }
        }
    }
    func castSpell(_ spell: Spell, for user: User) {
        guard user.runes >= spell.runeCost else { return }
        user.runes -= spell.runeCost
        
        let duration: TimeInterval = 600 // Default 10 minutes
        
        switch spell.effect {
        case .doubleXP:
            applyBuff(user: user, effect: .doubleXP, duration: duration)
        case .doubleGold:
            applyBuff(user: user, effect: .doubleGold, duration: duration)
        case .xpBoost(let stat, let multiplier):
            applyBuff(user: user, effect: .xpBoost(stat, multiplier), duration: duration)
        case .goldBoost(let multiplier):
            applyBuff(user: user, effect: .goldBoost(multiplier), duration: duration)
        case .runeBoost(let multiplier):
            applyBuff(user: user, effect: .runeBoost(multiplier), duration: duration)
        case .willpowerGeneration(let amount):
            applyBuff(user: user, effect: .willpowerGeneration(amount), duration: duration)
        case .reducedUpgradeCost(let percentage):
            applyBuff(user: user, effect: .reducedUpgradeCost(percentage), duration: duration)
        case .guildXpBoost(let multiplier):
            applyBuff(user: user, effect: .guildXpBoost(multiplier), duration: duration)
        case .plantGrowthSpeed(let multiplier):
            applyBuff(user: user, effect: .plantGrowthSpeed(multiplier), duration: duration)
        case .echoBoost(let multiplier):
            applyBuff(user: user, effect: .echoBoost(multiplier), duration: duration)
        }
    }

    private func applyBuff(user: User, effect: SpellEffect, duration: TimeInterval) {
        var finalDuration = duration
        // Apply buff duration increase from permanent bonuses
        if user.appliedBonuses.contains(.buffDurationIncrease) {
            finalDuration *= 1.10 // 10% longer
        }
        user.activeBuffs[effect] = Date().addingTimeInterval(finalDuration)
    }

    func cleanupExpiredBuffs(for user: User) {
        for (effect, expiryDate) in user.activeBuffs {
            if Date() > expiryDate { user.activeBuffs.removeValue(forKey: effect) }
        }
    }
}

// MARK: - Spell Effect Presentation Helpers
extension SpellEffect {
    var displayName: String {
        switch self {
        case .doubleXP: return "Double XP"
        case .doubleGold: return "Double Gold"
        case .xpBoost(let stat, let multiplier): return "+\(Int(multiplier * 100))% \(stat.rawValue.capitalized) XP"
        case .goldBoost(let multiplier): return "+\(Int(multiplier * 100))% Gold"
        case .runeBoost(let multiplier): return "+\(Int(multiplier * 100))% Runes"
        case .willpowerGeneration(let amount): return "+\(amount) Willpower/min"
        case .reducedUpgradeCost(let percentage): return "-\(Int(percentage * 100))% Upgrade Cost"
        case .guildXpBoost(let multiplier): return "+\(Int(multiplier * 100))% Guild XP"
        case .plantGrowthSpeed(let multiplier): return "+\(Int(multiplier * 100))% Plant Growth"
        case .echoBoost(let multiplier): return "+\(Int(multiplier * 100))% Echoes"
        }
    }
    var systemImage: String {
        switch self {
        case .doubleXP: return "sparkles"
        case .doubleGold: return "dollarsign.circle.fill"
        case .xpBoost: return "brain.head.profile"
        case .goldBoost: return "creditcard.circle.fill"
        case .runeBoost: return "circle.hexagonpath.fill"
        case .willpowerGeneration: return "bolt.heart.fill"
        case .reducedUpgradeCost: return "arrow.down.circle.fill"
        case .guildXpBoost: return "person.3.fill"
        case .plantGrowthSpeed: return "leaf.fill"
        case .echoBoost: return "speaker.wave.2.circle.fill"
        }
    }
}


// MARK: - Obsidian Gymnasium Manager

final class ObsidianGymnasiumManager {
    static let shared = ObsidianGymnasiumManager()
    private init() {}
    func initializeStatues(for user: User, context: ModelContext) {
        guard user.statues?.isEmpty ?? true else { return }
        let masterList = ItemDatabase.shared.masterStatueList
        for template in masterList {
            let newStatue = Statue(id: template.id, name: template.name, description: template.statueDescription, requiredWillpower: template.requiredWillpower, reward: template.reward, owner: user)
            context.insert(newStatue)
            user.statues?.append(newStatue)
        }
        user.currentStatueID = masterList.first?.id
    }
    func chiselStatue(for user: User, amount: Int) {
        guard let statueId = user.currentStatueID, let currentStatue = user.statues?.first(where: { $0.id == statueId }), !currentStatue.isComplete else { return }
        let amountToChisel = min(amount, user.willpower)
        guard amountToChisel > 0 else { return }
        user.willpower -= amountToChisel
        currentStatue.currentWillpower += amountToChisel
    }
    func completeStatue(for user: User, context: ModelContext) {
        guard let statueId = user.currentStatueID, let completedStatue = user.statues?.first(where: { $0.id == statueId }), completedStatue.isComplete else { return }
        user.appliedBonuses.append(completedStatue.reward)
        let masterList = ItemDatabase.shared.masterStatueList
        if let currentIndex = masterList.firstIndex(where: { $0.id == completedStatue.id }) {
            if currentIndex + 1 < masterList.count { user.currentStatueID = masterList[currentIndex + 1].id }
            else { user.currentStatueID = nil }
        }
    }
}


// MARK: - Daily Focus Manager

final class DailyFocusManager: ObservableObject {
    static let shared = DailyFocusManager()
    @Published private(set) var currentFocus: ChimeraStat
    private init() { self.currentFocus = ChimeraStat.allCases.randomElement() ?? .discipline }
}

// MARK: - Challenge Manager

final class ChallengeManager: ObservableObject {
    static let shared = ChallengeManager()
    private init() {}
    private let challengeTemplates: [WeeklyChallenge] = [
        .init(title: "The Scholar", challengeDescription: "Complete 5 Intellect tasks.", goal: 5, statRequirement: ChimeraStat.intellect),
        .init(title: "The Reflective Mind", challengeDescription: "Create 3 journal entries.", goal: 3, isJournalingChallenge: true),
        .init(title: "The Disciplined", challengeDescription: "Complete 5 Discipline tasks.", goal: 5, statRequirement: ChimeraStat.discipline),
        .init(title: "The Creator", challengeDescription: "Complete 5 Creativity tasks.", goal: 5, statRequirement: ChimeraStat.creativity)
    ]
    func generateWeeklyChallenges(for user: User, context: ModelContext) { if user.challenges?.isEmpty ?? true { user.challenges = Array(challengeTemplates.shuffled().prefix(3)) } }
    func updateChallengeProgress(for task: Task, on user: User) { guard let c = user.challenges else { return }; for ch in c where !ch.isCompleted { if ch.statRequirement == task.associatedStat { ch.progress += 1 } } }
    func updateChallengeProgressForJournaling(on user: User) { guard let c = user.challenges else { return }; for ch in c where !ch.isCompleted { if ch.isJournalingChallenge { ch.progress += 1 } } }
}


// MARK: - Game Logic Manager

final class GameLogicManager {
    static let shared = GameLogicManager()
    private let xpCurve: [Int]
    private init() {
        var curve = [0]; var points = 0.0
        for level in 1...99 {
            points += floor(Double(level) + 300.0 * pow(2.0, Double(level) / 7.0))
            curve.append(Int(floor(points / 4.0)))
        }
        self.xpCurve = curve
    }
    func xpRequired(for level: Int) -> Int {
        guard level > 0 && level < xpCurve.count else { return xpCurve.last ?? Int.max }
        return xpCurve[level]
    }
    func awardXP(for task: Task, to user: User) -> (didLevelUp: Bool, didEvolve: Bool) {
        var baseXP = Double(getBaseXP(for: task.difficulty))
        if task.associatedStat == DailyFocusManager.shared.currentFocus { baseXP *= 1.5 }
        if user.appliedBonuses.contains(.xpBoost) { baseXP *= 1.01 }
        // Apply XP boost from spells
        for (effect, _) in user.activeBuffs {
            if case .xpBoost(_, let multiplier) = effect {
                baseXP *= (1.0 + multiplier)
            }
        }
        if user.isDoubleXpNextTask { baseXP *= 2.0; user.isDoubleXpNextTask = false }
        user.totalXP += Int(baseXP)
        let subTaskXP = (task.subTasks?.filter { $0.isCompleted }.count ?? 0) * 5
        user.totalXP += subTaskXP
        var didEvolve = false
        if let chimera = user.chimera {
            var statGain = Int(baseXP) / 10
            statGain += getBonus(for: task.associatedStat, from: user)
            updateChimeraStat(chimera, for: task.associatedStat, amount: statGain)
            didEvolve = ChimeraEvolutionManager.shared.checkForEvolution(chimera: chimera)
        }
        ChallengeManager.shared.updateChallengeProgress(for: task, on: user)
        let didLevelUp = checkForLevelUp(user: user)
        return (didLevelUp, didEvolve)
    }
    func awardXP(for dailyTask: TaskItem, to user: User) -> (didLevelUp: Bool, didEvolve: Bool, didSkillLevelUp: Bool, skillName: String, newLevel: Int) {
        var xpGained = Double(dailyTask.xp)
        if user.appliedBonuses.contains(.xpBoost) { xpGained *= 1.01 }
        // Apply XP boost from spells
        for (effect, _) in user.activeBuffs {
            if case .xpBoost(_, let multiplier) = effect {
                xpGained *= (1.0 + multiplier)
            }
        }
        if user.isDoubleXpNextTask { xpGained *= 2.0; user.isDoubleXpNextTask = false }
        user.totalXP += Int(xpGained)
        if dailyTask.category == .strength { user.willpower += dailyTask.xp }
        QuestManager.shared.updateQuestProgress(forCompletedTask: dailyTask, on: user)
        let (didSkillLevelUp, skillName, newLevel) = grantXP(to: dailyTask.category, amount: dailyTask.xp, for: user)
        var didEvolve = false
        if let chimera = user.chimera {
            let chimeraStat = mapSkillToChimeraStat(dailyTask.category)
            var statGain = dailyTask.xp / 10
            statGain += getBonus(for: chimeraStat, from: user)
            updateChimeraStat(chimera, for: chimeraStat, amount: statGain)
            didEvolve = ChimeraEvolutionManager.shared.checkForEvolution(chimera: chimera)
        }
        let didPlayerLevelUp = checkForLevelUp(user: user)
        return (didPlayerLevelUp, didEvolve, didSkillLevelUp, skillName, newLevel)
    }
    func awardXPForJournaling(to user: User) -> (didLevelUp: Bool, didEvolve: Bool) {
        var journalingXP = 50.0
        if user.appliedBonuses.contains(.xpBoost) { journalingXP *= 1.01 }
        // Apply XP boost from spells
        for (effect, _) in user.activeBuffs {
            if case .xpBoost(_, let multiplier) = effect {
                journalingXP *= (1.0 + multiplier)
            }
        }
        if user.isDoubleXpNextTask { journalingXP *= 2.0; user.isDoubleXpNextTask = false }
        user.totalXP += Int(journalingXP)
        var didEvolve = false
        if let chimera = user.chimera {
            var statGain = Int(journalingXP) / 10
            statGain += getBonus(for: .mindfulness, from: user)
            updateChimeraStat(chimera, for: .mindfulness, amount: statGain)
            didEvolve = ChimeraEvolutionManager.shared.checkForEvolution(chimera: chimera)
        }
        ChallengeManager.shared.updateChallengeProgressForJournaling(on: user)
        let didLevelUp = checkForLevelUp(user: user)
        return (didLevelUp, didEvolve)
    }
    private func checkForLevelUp(user: User) -> Bool {
        let xpForNextLevel = xpRequired(for: user.level + 1)
        if user.totalXP >= xpForNextLevel {
            user.level += 1; user.gold += 100; 
        // Apply rune boost from spells
        var runesGained = 1
        for (effect, _) in user.activeBuffs {
            if case .runeBoost(let multiplier) = effect {
                runesGained = Int(Double(runesGained) * (1.0 + multiplier))
            }
        }
        user.runes += runesGained
            _ = checkForLevelUp(user: user)
            return true
        }
        return false
    }
    func grantXP(to skill: SkillCategory, amount: Int, for user: User) -> (didLevelUp: Bool, skillName: String, newLevel: Int) {
        var didLevelUp = false; var newLevel = 0
        switch skill {
        case .strength: user.xpStrength += amount; while user.xpStrength >= 100 { user.xpStrength -= 100; user.levelStrength += 1; didLevelUp = true }; newLevel = user.levelStrength
        case .mind: user.xpMind += amount; while user.xpMind >= 100 { user.xpMind -= 100; user.levelMind += 1; didLevelUp = true }; newLevel = user.levelMind
        case .joy: user.xpJoy += amount; while user.xpJoy >= 100 { user.xpJoy -= 100; user.levelJoy += 1; didLevelUp = true }; newLevel = user.levelJoy
        case .vitality: user.xpVitality += amount; while user.xpVitality >= 100 { user.xpVitality -= 100; user.levelVitality += 1; didLevelUp = true }; newLevel = user.levelVitality
        case .awareness: user.xpAwareness += amount; while user.xpAwareness >= 100 { user.xpAwareness -= 100; user.levelAwareness += 1; didLevelUp = true }; newLevel = user.levelAwareness
        case .flow: user.xpFlow += amount; while user.xpFlow >= 100 { user.xpFlow -= 100; user.levelFlow += 1; didLevelUp = true }; newLevel = user.levelFlow
        default: break
        }
        return (didLevelUp, skill.rawValue.capitalized, newLevel)
    }
    private func getBaseXP(for difficulty: TaskDifficulty) -> Int {
        switch difficulty {
        case .trivial: return 10; case .easy: return 25; case .medium: return 50
        case .hard: return 100; case .epic: return 250
        }
    }

    private func getBonus(for stat: ChimeraStat, from user: User) -> Int {
        return EquipmentManager.shared.getBonuses(for: user)
            .filter { $0.stat == stat }
            .reduce(0) { $0 + $1.value }
    }

    private func updateChimeraStat(_ chimera: Chimera, for stat: ChimeraStat, amount: Int) {
        switch stat {
        case .discipline: chimera.discipline += amount; case .mindfulness: chimera.mindfulness += amount
        case .intellect: chimera.intellect += amount; case .creativity: chimera.creativity += amount
        case .resilience: chimera.resilience += amount
        }
    }
    private func mapSkillToChimeraStat(_ skill: SkillCategory) -> ChimeraStat {
        switch skill {
        case .strength, .vitality: return .discipline
        case .mind, .awareness: return .intellect
        case .joy, .flow: return .creativity
        default: return .resilience
        }
    }
}


// MARK: - Chimera Evolution Manager
final class ChimeraEvolutionManager {
    static let shared = ChimeraEvolutionManager()
    private init() {}
    private struct EvolutionRule { let stat: ChimeraStat; let threshold: Int; let partID: String; let partType: PartType; enum PartType { case head, body, aura } }
    private let evolutionTable: [EvolutionRule] = [
        .init(stat: .discipline, threshold: 100, partID: "body_armor_t1", partType: .body), .init(stat: .discipline, threshold: 500, partID: "body_armor_t2", partType: .body),
        .init(stat: .mindfulness, threshold: 100, partID: "aura_subtle_t1", partType: .aura), .init(stat: .mindfulness, threshold: 500, partID: "aura_strong_t2", partType: .aura),
        .init(stat: .intellect, threshold: 100, partID: "head_runes_t1", partType: .head), .init(stat: .intellect, threshold: 500, partID: "head_runes_t2", partType: .head),
        .init(stat: .creativity, threshold: 100, partID: "body_vibrant_t1", partType: .body), .init(stat: .creativity, threshold: 500, partID: "head_feathers_t2", partType: .head),
    ]
    func checkForEvolution(chimera: Chimera) -> Bool {
        var didEvolve = false
        for rule in evolutionTable {
            if chimera.statValue(for: rule.stat) >= rule.threshold {
                if !isPartApplied(chimera: chimera, partID: rule.partID, for: rule.partType) {
                    applyEvolution(chimera: chimera, rule: rule); didEvolve = true
                }
            }
        }
        return didEvolve
    }
    private func applyEvolution(chimera: Chimera, rule: EvolutionRule) {
        switch rule.partType { case .head: chimera.headPartID = rule.partID; case .body: chimera.bodyPartID = rule.partID; case .aura: chimera.auraEffectID = rule.partID }
    }
    private func isPartApplied(chimera: Chimera, partID: String, for partType: EvolutionRule.PartType) -> Bool {
        switch partType { case .head: return chimera.headPartID == partID; case .body: return chimera.bodyPartID == partID; case .aura: return chimera.auraEffectID == partID }
    }
}
private extension Chimera {
    func statValue(for stat: ChimeraStat) -> Int {
        switch stat { case .discipline: return self.discipline; case .mindfulness: return self.mindfulness; case .intellect: return self.intellect; case .creativity: return self.creativity; case .resilience: return self.resilience }
    }
}

// MARK: - Sensory Feedback & AI Managers
final class SensoryFeedbackManager {
    static let shared = SensoryFeedbackManager(); private var audioPlayer: AVAudioPlayer?; private init() {}
    enum GameEvent { case taskCompleted, subTaskCompleted, levelUp, chimeraEvolved, journalSaved, skillLevelUp }
    func trigger(for event: GameEvent) {
        switch event {
        case .taskCompleted: playSound(named: "complete_positive.wav"); case .subTaskCompleted: playSound(named: "click_subtle.wav")
        case .levelUp: playSound(named: "level_up_fanfare.wav"); case .chimeraEvolved: playSound(named: "magic_chime.wav"); case .journalSaved: playSound(named: "page_turn.wav")
        case .skillLevelUp: playSound(named: "level_up_short.wav")
        }
    }
    private func playSound(named fileName: String) {
        guard let url = Bundle.main.url(forResource: fileName, withExtension: nil) else { print("⚠️ Sound file not found: \(fileName)."); return }
        do { audioPlayer = try AVAudioPlayer(contentsOf: url); audioPlayer?.play() } catch { print("🚨 Could not play sound file \(fileName). Error: \(error.localizedDescription)") }
    }
}
final class AIManager {
    static let shared = AIManager(); private init() {}
    func decompose(taskTitle: String, completion: @escaping ([String]) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { completion(["Step 1 for \(taskTitle)", "Step 2 for \(taskTitle)", "Step 3 for \(taskTitle)"]) }
    }
}
