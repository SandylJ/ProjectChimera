import Foundation
import SwiftData

// MARK: - Supporting Enums & Structs

enum TaskDifficulty: String, Codable, CaseIterable { case trivial, easy, medium, hard, epic }
enum ChimeraStat: String, Codable, CaseIterable { case discipline, mindfulness, intellect, creativity, resilience }

enum SkillCategory: String, CaseIterable, Identifiable, Codable {
    var id: String { rawValue }
    case strength, mind, joy, vitality, awareness, flow, finance, other
}

enum GuildPerk: String, Codable, CaseIterable {
    case increasedGuildXp, reducedUpgradeCost, increasedBountyRewards

    var description: String {
        switch self {
        case .increasedGuildXp: return "+10% Guild XP from all sources"
        case .reducedUpgradeCost: return "-5% Gold cost for Guild Member upgrades"
        case .increasedBountyRewards: return "+10% Guild Seals from Bounties"
        }
    }
}

enum PermanentBonus: String, Codable {
    case xpBoost, newDailyQuest, buffDurationIncrease
    var description: String {
        switch self {
        case .xpBoost: return "+1% XP from all sources"
        case .newDailyQuest: return "Unlocks a new Daily Sanctuary Quest"
        case .buffDurationIncrease: return "All positive buffs last 10% longer"
        }
    }
}

enum QuestType: Codable {
    case milestone(category: SkillCategory, count: Int)
    case streak(category: SkillCategory, days: Int)
    case exploration(categories: [SkillCategory])
}

enum QuestStatus: String, Codable {
    case available, active, completed
}

enum ExpeditionMode: String, Codable, CaseIterable {
    case all, combat, gathering
}

enum LootReward: Codable, Hashable, Identifiable {
    var id: String {
        switch self {
        case .currency(let amount):
            return "currency_\(amount)"
        case .item(let id, let quantity):
            return "item_\(id)_\(quantity)"
        case .experienceBurst(let skill, let amount):
            return "xp_\(skill.rawValue)_\(amount)"
        case .runes(let amount):
            return "runes_\(amount)"
        case .echoes(let amount):
            return "echoes_\(Int(amount))"
        }
    }
    case currency(Int)
    case item(id: String, quantity: Int)
    case experienceBurst(skill: SkillCategory, amount: Int)
    case runes(Int)
    case echoes(Double) // New case for Echoes
}

enum SpellEffect: Codable, Hashable {
    case doubleXP
    case doubleGold
    case xpBoost(ChimeraStat, Double)
    case goldBoost(Double)
    case runeBoost(Double)
    case willpowerGeneration(Int)
    case reducedUpgradeCost(Double)
    case guildXpBoost(Double)
    case plantGrowthSpeed(Double)
    case echoBoost(Double)
}

struct Spell: Codable, Hashable, Identifiable {
    var id: String; let name: String; let description: String; let requiredLevel: Int; let runeCost: Int; let effect: SpellEffect
}

struct Recipe: Codable, Hashable, Identifiable {
    var id: String
    let name: String
    let craftedItemID: String
    let requiredMaterials: [String: Int]
    let requiredGold: Int
    var craftedItem: Item? { ItemDatabase.shared.getItem(id: craftedItemID) }
}

// --- NEW: Struct for the Shop System ---
struct TreasureChest: Codable, Hashable, Identifiable {
    var id: String
    let name: String
    let description: String
    let cost: Int
    let keyItemID: String? // e.g., "item_ancient_key"
    let rarity: Rarity
    let icon: String
    let lootTable: [LootReward]
    let rewardCount: ClosedRange<Int> // e.g., 2...5 rewards
}


public enum Rarity: String, Codable { case common, rare, epic, legendary }

struct Item: Codable, Hashable, Identifiable {
    var id: String
    let name: String
    let description: String
    let itemType: ItemType
    let rarity: Rarity
    let icon: String
    let plantableType: PlantableType?
    let consumableEffect: ConsumableEffect?
    let growTime: TimeInterval?
    let harvestReward: HarvestReward?
    let slot: EquipmentSlot?
    let bonuses: [EquipmentBonus]?

    enum ItemType: String, Codable { case consumable, material, plantable, special, key, equippable } // Added 'equippable' type
    enum PlantableType: String, Codable { case habitSeed, crop, treeSapling }
    enum ConsumableEffect: Codable, Hashable { case experienceBurst(skill: ChimeraStat, amount: Int), refreshRandomTask }
    enum HarvestReward: Codable, Hashable {
        case currency(Int)
        case item(id: String, quantity: Int)
        case experienceBurst(skill: SkillCategory, amount: Int)
    }
}


enum EquipmentSlot: String, Codable, CaseIterable {
    case head, chest, hands, tool
}

struct EquipmentBonus: Codable, Hashable {
    let stat: ChimeraStat
    let value: Int
}


// MARK: - Core Data Models

@Model
final class User {
    var id: UUID
    var username: String; var joinDate: Date; var level: Int; var totalXP: Int; var currency: Int
    var xpStrength: Int; var levelStrength: Int; var xpMind: Int; var levelMind: Int
    var xpJoy: Int; var levelJoy: Int; var xpVitality: Int; var levelVitality: Int
    var xpAwareness: Int; var levelAwareness: Int; var xpFlow: Int; var levelFlow: Int
    var willpower: Int = 0
    var currentStatueID: UUID?
    private var appliedBonusesData: Data = Data()
    var appliedBonuses: [PermanentBonus] {
        get { (try? JSONDecoder().decode([PermanentBonus].self, from: appliedBonusesData)) ?? [] }
        set { appliedBonusesData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }
    var runes: Int = 5
    var isDoubleXpNextTask: Bool = false
    // Unified currency alias for clarity throughout the codebase
    var gold: Int {
        get { currency }
        set { currency = newValue }
    }

    // Passive Hunt Tracking: per-enemy kill tally and unclaimed hunt gold
    private var huntKillTallyData: Data = Data()
    var huntKillTally: [String: Int] {
        get { (try? JSONDecoder().decode([String: Int].self, from: huntKillTallyData)) ?? [:] }
        set { huntKillTallyData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }
    var unclaimedHuntGold: Int = 0
    var unclaimedHuntItems: [UnclaimedHuntItem] = []
    private var unlockedSpellIDsData: Data = Data()
    var unlockedSpellIDs: [String] {
        get { (try? JSONDecoder().decode([String].self, from: unlockedSpellIDsData)) ?? [] }
        set { unlockedSpellIDsData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }
    private var activeBuffsData: Data = Data()
    var activeBuffs: [SpellEffect: Date] {
        get { (try? JSONDecoder().decode([SpellEffect: Date].self, from: activeBuffsData)) ?? [:] }
        set { activeBuffsData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    var chimera: Chimera?
    var challenges: [WeeklyChallenge]?
    var inventory: [InventoryItem]? = []
    var plantedHabitSeeds: [PlantedHabitSeed]? = []
    var plantedCrops: [PlantedCrop]? = []
    var plantedTrees: [PlantedTree]? = []
    var guildMembers: [GuildMember]? = []
    var activeExpeditions: [ActiveExpedition]? = []
    var statues: [Statue]? = []
    var quests: [Quest]? = []
    var guildBounties: [GuildBounty]? = []
    var achievements: [Achievement]? = []
    var altarOfWhispers: AltarOfWhispers?

    private var equippedItemsData: Data = Data()
    var equippedItems: [EquipmentSlot: String] {
        get { (try? JSONDecoder().decode([EquipmentSlot: String].self, from: equippedItemsData)) ?? [:] }
        set { equippedItemsData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    // --- NEW: Altar Courtesies (permanent cross-system bonuses unlocked at the Altar) ---
    private var altarCourtesiesData: Data = Data()
    /// Map of courtesy key -> level unlocked
    var altarCourtesies: [String: Int] {
        get { (try? JSONDecoder().decode([String: Int].self, from: altarCourtesiesData)) ?? [:] }
        set { altarCourtesiesData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    var guild: Guild?
    var team: Team?
    var guildSeals: Int = 0
    var teamPoints: Int = 0
    var eggs: [HatchableEgg]? = []
    var activeHunts: [ActiveHunt]? = []
    // Crafted items accumulated passively by crafting workers
    var unclaimedCraftedItems: [UnclaimedCraftedItem] = []

    // Track crafting progress per role (e.g., "leatherworker", "weaver", "spinner")
    private var craftingProgressData: Data = Data()
    var craftingProgress: [String: Double] {
        get { (try? JSONDecoder().decode([String: Double].self, from: craftingProgressData)) ?? [:] }
        set { craftingProgressData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    // --- NEW: Guild Automation ---
    private var guildAutomationData: Data = Data()
    var guildAutomation: GuildAutomationSettings {
        get { (try? JSONDecoder().decode(GuildAutomationSettings.self, from: guildAutomationData)) ?? GuildAutomationSettings.defaultSettings }
        set { guildAutomationData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }
    var automationProgressForager: Double = 0.0
    var lastAutomationRun: Date? = nil

    // --- NEW: Aggregated Guild Work Stats ---
    var totalSeedsPlantedByGuild: Int = 0
    var totalCropsPlantedByGuild: Int = 0
    var totalTreesPlantedByGuild: Int = 0
    var totalSeedsHarvestedByGuild: Int = 0
    var totalCropsHarvestedByGuild: Int = 0
    var totalTreesHarvestedByGuild: Int = 0
    var totalItemsFoundByGuild: Int = 0

    init(username: String) {
        self.id = UUID(); self.username = username; self.joinDate = .now; self.level = 1
        self.totalXP = 0; self.currency = 100; self.xpStrength = 0; self.levelStrength = 1
        self.xpMind = 0; self.levelMind = 1; self.xpJoy = 0; self.levelJoy = 1
        self.xpVitality = 0; self.levelVitality = 1; self.xpAwareness = 0; self.levelAwareness = 1
        self.xpFlow = 0; self.levelFlow = 1; self.chimera = Chimera(owner: self)
        self.challenges = []; self.inventory = []; self.plantedHabitSeeds = []
        self.plantedCrops = []; self.plantedTrees = []; self.guildMembers = []
        self.activeExpeditions = []; self.willpower = 0; self.statues = []; self.quests = []
        self.runes = 5; self.isDoubleXpNextTask = false; self.unlockedSpellIDs = []; self.activeBuffs = [:]
        self.unclaimedHuntGold = 0
        self.unclaimedCraftedItems = []
        self.craftingProgress = [:]
        // Initialize automation
        self.guildAutomation = GuildAutomationSettings.defaultSettings
        self.automationProgressForager = 0.0
        self.lastAutomationRun = nil
        // Initialize aggregated guild work stats
        self.totalSeedsPlantedByGuild = 0
        self.totalCropsPlantedByGuild = 0
        self.totalTreesPlantedByGuild = 0
        self.totalSeedsHarvestedByGuild = 0
        self.totalCropsHarvestedByGuild = 0
        self.totalTreesHarvestedByGuild = 0
        self.totalItemsFoundByGuild = 0
        // Courtesies default
        self.altarCourtesies = [:]
    }

    /// Some legacy code still expects a `name` property on `User`.
    /// Provide a computed wrapper around `username` for compatibility.
    var name: String {
        get { username }
        set { username = newValue }
    }
}

// --- NEW: Automation Settings Model ---
struct GuildAutomationSettings: Codable {
    var autoHarvestGarden: Bool
    var autoPlantHabitSeeds: Bool
    var preferredHabitSeedID: String?
    var gardenerMaintainPlots: Int
    var foragerGatherForAltar: Bool
    var seerAttuneAltar: Bool

    static let defaultSettings = GuildAutomationSettings(
        autoHarvestGarden: true,
        autoPlantHabitSeeds: false,
        preferredHabitSeedID: nil,
        gardenerMaintainPlots: 6,
        foragerGatherForAltar: false,
        seerAttuneAltar: true
    )
}


@Model
final class HatchableEgg {
    var id: UUID
    var eggType: String
    var requiredSteps: Int
    var currentSteps: Int
    var hatched: Bool
    private var rewardsData: Data = Data()
    var rewards: [LootReward] {
        get { (try? JSONDecoder().decode([LootReward].self, from: rewardsData)) ?? [] }
        set { rewardsData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }
    var owner: User?

    init(eggType: String, requiredSteps: Int, owner: User?) {
        self.id = UUID()
        self.eggType = eggType
        self.requiredSteps = requiredSteps
        self.currentSteps = 0
        self.hatched = false
        self.rewards = []
        self.owner = owner
    }

    var isReadyToHatch: Bool {
        currentSteps >= requiredSteps
    }
}


@Model
final class Guild {
    var id: UUID
    var name: String
    var level: Int
    var xp: Int
    private var unlockedPerksData: Data = Data()
    var unlockedPerks: [GuildPerk] {
        get { (try? JSONDecoder().decode([GuildPerk].self, from: unlockedPerksData)) ?? [] }
        set { unlockedPerksData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }
    var owner: User?

    init(owner: User?) {
        self.id = UUID()
        self.name = "The Rising Stars"
        self.level = 1
        self.xp = 0
        self.owner = owner
        self.unlockedPerks = []
    }

    var xpToNextLevel: Int {
        return level * 1000 // Simple scaling for now
    }
}


@Model
final class Team {
    var id: UUID
    var name: String
    var members: [User]?

    init(name: String, owner: User) {
        self.id = UUID()
        self.name = name
        self.members = [owner]
    }
}


@Model
final class GuildBounty {
    var id: UUID
    var title: String
    var bountyDescription: String // Renamed from description
    var requiredProgress: Int
    var currentProgress: Int
    var guildXpReward: Int
    var guildSealReward: Int
    var isActive: Bool
    var owner: User?
    var targetEnemyID: String? // Optional target enemy for combat bounties

    init(title: String, bountyDescription: String, requiredProgress: Int, guildXpReward: Int, guildSealReward: Int, owner: User?, targetEnemyID: String? = nil) { // Updated initializer
        self.id = UUID()
        self.title = title
        self.bountyDescription = bountyDescription
        self.requiredProgress = requiredProgress
        self.currentProgress = 0
        self.guildXpReward = guildXpReward
        self.guildSealReward = guildSealReward
        self.isActive = true
        self.owner = owner
        self.targetEnemyID = targetEnemyID
    }
}


@Model
final class Achievement {
    var id: UUID
    var title: String
    var achievementDescription: String
    var dateEarned: Date
    var owner: User?

    init(title: String, achievementDescription: String, dateEarned: Date = .now, owner: User?) {
        self.id = UUID()
        self.title = title
        self.achievementDescription = achievementDescription
        self.dateEarned = dateEarned
        self.owner = owner
    }
}


@Model
final class Quest {
    var id: UUID
    var title: String; var questDescription: String; var progress: Int; var lastProgressDate: Date?
    private var typeData: Data = Data(); private var rewardsData: Data = Data(); private var statusData: Data = Data()
    var type: QuestType {
        get { (try? JSONDecoder().decode(QuestType.self, from: typeData)) ?? .milestone(category: .other, count: 1) }
        set { typeData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }
    var rewards: [LootReward] {
        get { (try? JSONDecoder().decode([LootReward].self, from: rewardsData)) ?? [] }
        set { rewardsData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }
    var status: QuestStatus {
        get {
            if let d = try? JSONDecoder().decode(QuestStatus.self, from: statusData) { return d }
            if let s = String(data: statusData, encoding: .utf8), let r = QuestStatus(rawValue: s) { return r }
            return .available
        }
        set { statusData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }
    var owner: User?
    init(id: UUID = UUID(), title: String, description: String, type: QuestType, rewards: [LootReward], owner: User?) {
        self.id = id; self.title = title; self.questDescription = description; self.progress = 0
        self.lastProgressDate = nil; self.owner = owner; self.type = type; self.rewards = rewards; self.status = .available
    }
    var objectiveDescription: String {
        switch type {
        case .milestone(let c, let n): return "Complete \(n) \(c.rawValue.capitalized) tasks."
        case .streak(let c, let d): return "Complete a \(c.rawValue.capitalized) task for \(d) days in a row."
        case .exploration(let c): return "Complete a task from each of these categories: \(c.map { $0.rawValue.capitalized }.joined(separator: ", "))."
        }
    }
}


@Model
final class Statue {
    var id: UUID
    var name: String; var statueDescription: String; var requiredWillpower: Int
    var currentWillpower: Int; var reward: PermanentBonus; var owner: User?
    init(id: UUID = UUID(), name: String, description: String, requiredWillpower: Int, reward: PermanentBonus, owner: User?) {
        self.id = UUID(); self.name = name; self.statueDescription = description; self.requiredWillpower = requiredWillpower
        self.currentWillpower = 0; self.reward = reward; self.owner = owner
    }
    var progress: Double { requiredWillpower > 0 ? Double(currentWillpower) / Double(requiredWillpower) : 0 }
    var isComplete: Bool { currentWillpower >= requiredWillpower }
}


@Model
final class Chimera {
    var id: UUID; var name: String; var discipline: Int; var mindfulness: Int
    var intellect: Int; var creativity: Int; var resilience: Int; var headPartID: String
    var bodyPartID: String; var auraEffectID: String; var cosmeticHeadItemID: String; var owner: User?
    init(owner: User) {
        self.id = UUID(); self.name = "Chimera"; self.discipline = 0; self.mindfulness = 0
        self.intellect = 0; self.creativity = 0; self.resilience = 0; self.headPartID = "base_head_01"
        self.bodyPartID = "base_body_01"; self.auraEffectID = "none"; self.cosmeticHeadItemID = "none"; self.owner = owner
    }
}


@Model
final class Task {
    var id: UUID; var title: String; var details: String?; var creationDate: Date
    var dueDate: Date?; var isCompleted: Bool; var completionDate: Date?; var difficulty: TaskDifficulty
    var associatedStat: ChimeraStat
    var subTasks: [SubTask]?
    init(title: String, details: String? = nil, dueDate: Date? = nil, difficulty: TaskDifficulty, associatedStat: ChimeraStat) {
        self.id = UUID(); self.title = title; self.details = details; self.creationDate = .now; self.dueDate = dueDate
        self.isCompleted = false; self.completionDate = nil; self.difficulty = difficulty; self.associatedStat = associatedStat
    }
}

// Legacy type alias for older code paths
typealias UserTask = Task


@Model
final class SubTask {
    var id: UUID; var title: String; var isCompleted: Bool; var parentTask: Task?
    init(title: String) { self.id = UUID(); self.title = title; self.isCompleted = false }
}


@Model
final class JournalEntry {
    var id: UUID; var date: Date; var moodRating: Int; var entryText: String; var promptUsed: String?
    init(date: Date, moodRating: Int, entryText: String, promptUsed: String?) {
        self.id = UUID(); self.date = date; self.moodRating = moodRating; self.entryText = entryText; self.promptUsed = promptUsed
    }
}


@Model
final class WeeklyChallenge {
    var id: UUID; var title: String; var challengeDescription: String; var progress: Int
    var goal: Int; var isJournalingChallenge: Bool; var statRequirement: ChimeraStat?
    var isCompleted: Bool { progress >= goal }
    init(id: UUID = UUID(), title: String, challengeDescription: String, progress: Int = 0, goal: Int, isJournalingChallenge: Bool = false, statRequirement: ChimeraStat? = nil) {
        self.id = id; self.title = title; self.challengeDescription = challengeDescription; self.progress = progress
        self.goal = goal; self.isJournalingChallenge = isJournalingChallenge; self.statRequirement = statRequirement
    }
}


@Model
final class InventoryItem {
    var id: UUID; var itemID: String; var quantity: Int; var owner: User?
    init(itemID: String, quantity: Int, owner: User?) {
        self.id = UUID(); self.itemID = itemID; self.quantity = quantity; self.owner = owner
    }
}


@Model
final class PlantedHabitSeed {
    var id: UUID; var seedID: String; var plantedAt: Date; var owner: User?
    var seed: Item? { ItemDatabase.shared.getItem(id: seedID) }
    init(seedID: String, plantedAt: Date, owner: User?) {
        self.id = UUID(); self.seedID = seedID; self.plantedAt = plantedAt; self.owner = owner
    }
}


@Model
final class PlantedCrop {
    var id: UUID; var cropID: String; var plantedAt: Date; var owner: User?
    var crop: Item? { ItemDatabase.shared.getItem(id: cropID) } 
    init(cropID: String, plantedAt: Date, owner: User?) {
        self.id = UUID(); self.cropID = cropID; self.plantedAt = plantedAt; self.owner = owner
    }
}


@Model
final class PlantedTree {
    var id: UUID; var treeID: String; var plantedAt: Date; var owner: User?
    var tree: Item? { ItemDatabase.shared.getItem(id: treeID) }
    init(treeID: String, plantedAt: Date, owner: User?) {
        self.id = UUID(); self.treeID = treeID; self.plantedAt = plantedAt; self.owner = owner
    }
}


@Model
final class GuildMember {
    var id: UUID; var name: String; var role: Role; var level: Int
    var xp: Int; var isOnExpedition: Bool; var owner: User?
    enum Role: String, Codable, CaseIterable {
        case forager = "Forager", gardener = "Gardener", alchemist = "Alchemist", seer = "Seer", blacksmith = "Blacksmith"
        case leatherworker = "Leatherworker", weaver = "Weaver", spinner = "Spinner"
        case knight = "Knight", archer = "Archer", wizard = "Wizard", rogue = "Rogue", cleric = "Cleric"
    }
    init(name: String, role: Role, owner: User?) {
        self.id = UUID(); self.name = name; self.role = role; self.level = 1
        self.xp = 0; self.isOnExpedition = false; self.owner = owner
    }
    var roleDescription: String {
        switch self.role {
        case .forager: return "Passively finds seeds and materials over time."
        case .gardener: return "Automatically harvests ready plants from the Garden."
        case .alchemist: return "Periodically transmutes materials or brews simple potions."
        case .seer: return "Boosts the Altar of Whispers' Echo generation."
        case .blacksmith: return "Specializes in crafting and enhancing equipment."
        case .leatherworker: return "Tans hides into premium leathers over time."
        case .weaver: return "Weaves fine linen from gathered fibers passively."
        case .spinner: return "Spins raw flax into quality threads continuously."
        case .knight: return "Frontline fighter with steady damage and durability."
        case .archer: return "Ranged attacker with high single-target damage."
        case .wizard: return "Caster that deals bursty magic damage."
        case .rogue: return "Swift strikes with occasional critical bursts."
        case .cleric: return "Support that empowers the party's effectiveness."
        }
    }
    func effectDescription() -> String {
        switch self.role {
        case .forager: return "Finds an item every \(Int(3600 / Double(self.level))) seconds."
        case .gardener: return "Harvests have a \(self.level * 5)% chance to yield extra materials."
        case .alchemist: return "Every hour, has a \(self.level * 2)% chance to create a potion."
        case .seer: return "Increases Echo generation by \(self.level * 10)%."
        case .blacksmith: return "Can craft materials or enhance equipped items."
        case .leatherworker: return "Produces Tanned Leather at an increasing pace with level."
        case .weaver: return "Produces Linen over time; higher level means faster output."
        case .spinner: return "Produces Spun Flax passively; level reduces craft time."
        case .knight: return "Contributes ~\(Int(combatDPS())) DPS to hunts."
        case .archer: return "Contributes ~\(Int(combatDPS())) DPS to hunts."
        case .wizard: return "Contributes ~\(Int(combatDPS())) DPS to hunts."
        case .rogue: return "Contributes ~\(Int(combatDPS())) DPS to hunts."
        case .cleric: return "Boosts party DPS in hunts by 10% per level."
        }
    }
    func upgradeCost() -> Int { 100 * Int(pow(2.0, Double(self.level))) }

    func combatDPS() -> Double {
        switch role {
        case .knight: return 2.0 + Double(level) * 1.0
        case .archer: return 2.5 + Double(level) * 1.2
        case .wizard: return 1.5 + Double(level) * 1.6
        case .rogue: return 2.2 + Double(level) * 1.3
        case .cleric: return 0.5 + Double(level) * 0.5
        default: return 0.0
        }
    }
    var isCombatant: Bool { [.knight, .archer, .wizard, .rogue, .cleric].contains(role) }
}


@Model
final class ActiveExpedition {
    var id: UUID; var expeditionID: String; var memberIDs: [UUID]; var startTime: Date; var owner: User?
    var expedition: Expedition? { ItemDatabase.shared.getExpedition(id: expeditionID) }
    var endTime: Date { guard let e = expedition else { return startTime }; return startTime.addingTimeInterval(e.duration) }
    init(expeditionID: String, memberIDs: [UUID], startTime: Date, owner: User?) {
        self.id = UUID(); self.expeditionID = expeditionID; self.memberIDs = memberIDs; self.startTime = startTime; self.owner = owner
    }
}


@Model
final class ActiveHunt {
    var id: UUID
    var enemyID: String
    var memberIDs: [UUID]
    var killsAccumulated: Int
    var lastUpdated: Date
    var owner: User?

    init(enemyID: String, memberIDs: [UUID], owner: User?) {
        self.id = UUID()
        self.enemyID = enemyID
        self.memberIDs = memberIDs
        self.killsAccumulated = 0
        self.lastUpdated = Date()
        self.owner = owner
    }

    var enemy: Enemy? { 
        // For now, return nil to avoid loading issues
        // This can be implemented later when GameData is properly set up
        return nil
    }
}

struct Expedition: Codable, Identifiable {
    var id: String; let name: String; let description: String; let duration: TimeInterval
    let minMembers: Int; let requiredRoles: [GuildMember.Role]?; let lootTable: [String: Int]; let xpReward: Int
}

struct Enemy: Codable, Identifiable {
    var id: String
    let name: String
    let health: Double
    let goldPerKill: Int
}


@Model
final class AltarOfWhispers {
    var id: UUID
    var level: Int
    var echoes: Double
    var lastUpdated: Date
    var owner: User?

    // New upgrade levels
    var echoMultiplierLevel: Int
    var runeGenerationLevel: Int
    var goldGenerationLevel: Int

    init(owner: User?) {
        self.id = UUID()
        self.level = 1
        self.echoes = 0
        self.lastUpdated = Date()
        self.owner = owner
        
        // Initialize new properties
        self.echoMultiplierLevel = 1
        self.runeGenerationLevel = 0 // Start at 0, so the user has to buy the first level
        self.goldGenerationLevel = 0 // Start at 0
    }

    // --- COMPUTED PROPERTIES ---

    // Base Echoes per second from the main level
    var baseEchoesPerSecond: Double {
        return Double(level) * 0.1
    }

    // Echo multiplier from its own upgrade path
    var echoMultiplier: Double {
        return 1.0 + (Double(echoMultiplierLevel - 1) * 0.25) // +25% per level
    }
    
    // Total echoes per second
    var echoesPerSecond: Double {
        return baseEchoesPerSecond * echoMultiplier
    }

    // Runes generated per second
    var runesPerSecond: Double {
        return Double(runeGenerationLevel) * 0.001 // 1 rune every ~16 minutes at level 1
    }

    // Gold generated per second
    var goldPerSecond: Double {
        return Double(goldGenerationLevel) * 0.5 // 0.5 gold per second at level 1
    }

    // --- UPGRADE COSTS ---

    var upgradeCost: Double {
        return pow(10, Double(level))
    }
    
    var echoMultiplierUpgradeCost: Double {
        return pow(25, Double(echoMultiplierLevel))
    }

    var runeGenerationUpgradeCost: Double {
        return pow(100, Double(runeGenerationLevel + 1)) // Use +1 because it starts at 0
    }

    var goldGenerationUpgradeCost: Double {
        return pow(50, Double(goldGenerationLevel + 1)) // Use +1 because it starts at 0
    }
}

@Model
final class UnclaimedHuntItem {
    var id: UUID
    var itemID: String
    var quantity: Int
    var owner: User?
    
    init(itemID: String, quantity: Int, owner: User?) {
        self.id = UUID()
        self.itemID = itemID
        self.quantity = quantity
        self.owner = owner
    }
}

struct HuntItemDrop {
    let itemID: String
    let dropRate: Double
    let minQuantity: Int
    let maxQuantity: Int
}

// MARK: - Game Data (Not stored in SwiftData)

struct GameData {
    static let shared = GameData()
    let spells: [Spell]
    let recipes: [Recipe]
    let expeditions: [Expedition]
    let treasureChests: [TreasureChest]
    let enemies: [Enemy]

    private init() {
        self.spells = [
            Spell(id: "spell_double_xp", name: "Enlightenment", description: "Doubles XP gained from the next completed task.", requiredLevel: 5, runeCost: 2, effect: .doubleXP),
            Spell(id: "spell_double_gold", name: "Midas Touch", description: "Doubles Gold gained from the next completed task.", requiredLevel: 5, runeCost: 2, effect: .doubleGold),
            Spell(id: "spell_resilience_boost", name: "Iron Will", description: "Boosts Resilience XP gains by 20% for 1 hour.", requiredLevel: 8, runeCost: 5, effect: .xpBoost(.resilience, 1.2)),
            Spell(id: "spell_gold_boost", name: "Golden Hour", description: "Boosts all Gold gains by 15% for 1 hour.", requiredLevel: 10, runeCost: 8, effect: .goldBoost(1.15)),
            Spell(id: "spell_rune_boost", name: "Runic Focus", description: "Boosts Rune gains from all sources by 10% for 1 hour.", requiredLevel: 12, runeCost: 10, effect: .runeBoost(1.1)),
            Spell(id: "spell_surge_of_will", name: "Surge of Will", description: "Instantly generates 100 Willpower.", requiredLevel: 15, runeCost: 15, effect: .willpowerGeneration(100)),
            Spell(id: "spell_discount", name: "Frugal Mind", description: "Reduces the Gold cost of all Guild Member upgrades by 10% for 1 hour.", requiredLevel: 18, runeCost: 20, effect: .reducedUpgradeCost(0.9)),
            Spell(id: "spell_guild_xp", name: "Banner of Zeal", description: "Increases Guild XP earned by 25% for 4 hours.", requiredLevel: 20, runeCost: 25, effect: .guildXpBoost(1.25)),
            Spell(id: "spell_growth_speed", name: "Sun's Blessing", description: "Increases the growth speed of all plants in the Garden by 50% for 8 hours.", requiredLevel: 22, runeCost: 30, effect: .plantGrowthSpeed(1.5))
        ]
        self.recipes = [
            Recipe(id: "recipe_basic_potion", name: "Basic Potion", craftedItemID: "item_basic_potion", requiredMaterials: ["item_herb": 2], requiredGold: 10),
            Recipe(id: "recipe_strength_potion", name: "Strength Potion", craftedItemID: "item_strength_potion", requiredMaterials: ["item_herb": 3, "item_crystal": 1], requiredGold: 50)
        ]
        self.expeditions = [
            Expedition(id: "exp_forest_1", name: "Whispering Woods", description: "A short trek into the nearby woods.", duration: 3600, minMembers: 1, requiredRoles: nil, lootTable: ["item_herb": 3, "item_wood": 5], xpReward: 100),
            Expedition(id: "exp_cave_1", name: "Crystal Caves", description: "Explore a cave rumored to hold rare crystals.", duration: 14400, minMembers: 2, requiredRoles: [.forager, .gardener], lootTable: ["item_crystal": 2, "item_stone": 10], xpReward: 500)
        ]
        self.treasureChests = [
            TreasureChest(id: "chest_wooden", name: "Wooden Chest", description: "A simple chest often found by adventurers.", cost: 100, keyItemID: nil as String?, rarity: Rarity.common, icon: "chest_wooden_icon", lootTable: [
                LootReward.currency(50), LootReward.item(id: "item_herb", quantity: 2), LootReward.runes(1)
            ], rewardCount: 1...2),
            TreasureChest(id: "chest_iron", name: "Iron Chest", description: "A sturdy chest that requires a key.", cost: 0, keyItemID: "item_iron_key", rarity: Rarity.rare, icon: "chest_iron_icon", lootTable: [
                LootReward.currency(200), LootReward.item(id: "item_crystal", quantity: 1), LootReward.runes(5), LootReward.experienceBurst(skill: SkillCategory.other, amount: 100)
            ], rewardCount: 2...3),
            TreasureChest(id: "chest_ancient", name: "Ancient Chest", description: "A rare and valuable chest from a forgotten era.", cost: 1000, keyItemID: "item_ancient_key", rarity: Rarity.epic, icon: "chest_ancient_icon", lootTable: [
                LootReward.currency(1000), LootReward.item(id: "item_relic_fragment", quantity: 1), LootReward.runes(20), LootReward.echoes(50.0)
            ], rewardCount: 3...5)
        ]
        self.enemies = [
            Enemy(id: "enemy_goblin", name: "Goblin", health: 12.0, goldPerKill: 2),
            Enemy(id: "enemy_zombie", name: "Zombie", health: 30.0, goldPerKill: 4),
            Enemy(id: "enemy_spider", name: "Spider", health: 15.0, goldPerKill: 3),
            Enemy(id: "enemy_wolf", name: "Wolf", health: 20.0, goldPerKill: 3)
        ]
    }

    func getEnemy(id: String) -> Enemy? { enemies.first { $0.id == id } }
}

@Model
final class UnclaimedCraftedItem {
    var id: UUID
    var itemID: String
    var quantity: Int
    var owner: User?
    
    init(itemID: String, quantity: Int, owner: User?) {
        self.id = UUID()
        self.itemID = itemID
        self.quantity = quantity
        self.owner = owner
    }
}
