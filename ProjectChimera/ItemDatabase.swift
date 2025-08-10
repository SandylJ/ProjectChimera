import Foundation

/// Simple in-memory database of items, spells, recipes and templates used by
/// various game systems. The implementation is intentionally lightweight – it
/// only exposes the members referenced by the rest of the codebase so that the
/// project can compile without needing a full data set.
final class ItemDatabase {
    static let shared = ItemDatabase()
    private init() {
        // Items
        let itemList = ItemDatabase.createAllEquipment() + ItemDatabase.createAllItems()
        self.items = Dictionary(uniqueKeysWithValues: itemList.map { ($0.id, $0) })

        // Expeditions
        self.expeditions = ItemDatabase.createAllExpeditions()
        print("DEBUG: ItemDatabase initialized with \(self.expeditions.count) expeditions: \(self.expeditions.map { $0.id })")

        // Master Lists
        self.masterStatueList = ItemDatabase.createAllStatueTemplates()
        self.masterQuestList = ItemDatabase.createAllQuestTemplates()
        self.masterSpellList = ItemDatabase.createAllSpells()
        self.masterRecipeList = ItemDatabase.createAllRecipes()
        self.masterChestList = ItemDatabase.createAllChests()
    }

    // MARK: - Items
    private var items: [String: Item] = [:]

    func getItem(id: String) -> Item? {
        items[id]
    }

    /// Convenience helpers used by various views
    func getAllPlantables() -> [Item] { items.values.filter { $0.itemType == .plantable } }

    // MARK: - Spells
    var masterSpellList: [Spell] = [
        Spell(
            id: "spell_double_xp",
            name: "Double XP",
            description: "Earn double XP for a short time",
            requiredLevel: 1,
            runeCost: 1,
            effect: .doubleXP
        ),
        Spell(
            id: "spell_double_gold",
            name: "Double Gold",
            description: "Earn double gold for a short time",
            requiredLevel: 1,
            runeCost: 1,
            effect: .doubleGold
        ),
        Spell(
            id: "spell_echo_surge",
            name: "Echo Surge",
            description: "+50% Echoes for 10 minutes",
            requiredLevel: 5,
            runeCost: 2,
            effect: .echoBoost(0.5)
        )
    ]

    // MARK: - Recipes
    var masterRecipeList: [Recipe] = []
    // MARK: - Chests
    var masterChestList: [TreasureChest] = []
    // MARK: - Expeditions
    private var expeditions: [Expedition] = []
    func getAllExpeditions() -> [Expedition] { expeditions }
    func getExpedition(id: String) -> Expedition? { 
        let expedition = expeditions.first { $0.id == id }
        if expedition == nil {
            print("DEBUG: Failed to find expedition with ID: \(id)")
            print("DEBUG: Available expedition IDs: \(expeditions.map { $0.id })")
        }
        return expedition
    }

    // MARK: - Quest Templates
    struct QuestTemplate {
        let id: UUID
        let title: String
        let questDescription: String
        let type: QuestType
        let rewards: [LootReward]
    }

    var masterQuestList: [QuestTemplate] = []

    // MARK: - Statue Templates
    struct StatueTemplate {
        let id: UUID
        let name: String
        let statueDescription: String
        let requiredWillpower: Int
        let reward: PermanentBonus
    }

    var masterStatueList: [StatueTemplate] = []
}

// MARK: - Master Data Creation
private extension ItemDatabase {
    static func createAllChests() -> [TreasureChest] {
        return [
            TreasureChest(
                id: "chest_common",
                name: "Common Chest",
                description: "Contains a few simple rewards.",
                cost: 250,
                keyItemID: nil,
                rarity: .common,
                icon: "shippingbox.fill",
                lootTable: [
                    .currency(100),
                    .item(id: "seed_vigor", quantity: 1),
                    .item(id: "material_joyful_ember", quantity: 2)
                ],
                rewardCount: 1...2
            ),
            TreasureChest(
                id: "chest_rare",
                name: "Rare Chest",
                description: "Contains valuable materials and a chance for rare seeds.",
                cost: 1000,
                keyItemID: nil,
                rarity: .rare,
                icon: "archivebox.fill",
                lootTable: [
                    .currency(500),
                    .item(id: "seed_clarity", quantity: 1),
                    .item(id: "material_sunstone_shard", quantity: 1),
                    .runes(1)
                ],
                rewardCount: 2...3
            ),
            TreasureChest(
                id: "chest_ancient",
                name: "Ancient Chest",
                description: "A locked chest from a forgotten era. Requires a special key.",
                cost: 0,
                keyItemID: "item_ancient_key",
                rarity: .epic,
                icon: "treasurechest.fill",
                lootTable: [
                    .currency(2000),
                    .item(id: "seed_inspiration", quantity: 1),
                    .item(id: "tree_ironwood", quantity: 1),
                    .runes(5)
                ],
                rewardCount: 3...4
            )
        ]
    }

    static func createAllRecipes() -> [Recipe] {
        return [
            Recipe(
                id: "recipe_elixir_strength",
                name: "Elixir of Strength",
                craftedItemID: "item_elixir_strength",
                requiredMaterials: ["item_potion_vigor": 2, "material_sunstone_shard": 1],
                requiredGold: 100
            ),
            Recipe(
                id: "recipe_scroll_fortune",
                name: "Scroll of Fortune",
                craftedItemID: "item_scroll_fortune",
                requiredMaterials: ["material_joyful_ember": 5, "material_essence": 2],
                requiredGold: 250
            )
        ]
    }

    static func createAllSpells() -> [Spell] {
        return [
            // Existing/Basic Spells
            Spell(id: "spell_surge_of_power", name: "Surge of Power", description: "Your next completed task grants double XP.", requiredLevel: 2, runeCost: 1, effect: .doubleXP),
            Spell(id: "spell_midas_touch", name: "Midas Touch", description: "For 10 minutes, all tasks grant double gold.", requiredLevel: 5, runeCost: 2, effect: .doubleGold),

            // Attribute-boosting Spells
            Spell(id: "spell_mind_amplification", name: "Mind Amplification", description: "For 5 minutes, gain +50% XP for Mind tasks.", requiredLevel: 3, runeCost: 2, effect: .xpBoost(.intellect, 0.5)),
            Spell(id: "spell_disciplined_focus", name: "Disciplined Focus", description: "For 5 minutes, gain +50% XP for Discipline tasks.", requiredLevel: 3, runeCost: 2, effect: .xpBoost(.discipline, 0.5)),
            Spell(id: "spell_creative_spark", name: "Creative Spark", description: "For 5 minutes, gain +50% XP for Creativity tasks.", requiredLevel: 3, runeCost: 2, effect: .xpBoost(.creativity, 0.5)),
            Spell(id: "spell_resilient_spirit", name: "Resilient Spirit", description: "For 5 minutes, gain +50% XP for Resilience tasks.", requiredLevel: 3, runeCost: 2, effect: .xpBoost(.resilience, 0.5)),
            Spell(id: "spell_mindfulness_aura", name: "Mindfulness Aura", description: "For 5 minutes, gain +50% XP for Mindfulness tasks.", requiredLevel: 3, runeCost: 2, effect: .xpBoost(.mindfulness, 0.5)),

            // Economy/Meta Spells
            Spell(id: "spell_golden_harvest", name: "Golden Harvest", description: "For 10 minutes, all gold drops are increased by 25%.", requiredLevel: 7, runeCost: 3, effect: .goldBoost(0.25)),
            Spell(id: "spell_rune_surge", name: "Rune Surge", description: "For 10 minutes, all rune drops are increased by 10%.", requiredLevel: 10, runeCost: 4, effect: .runeBoost(0.10)),
            Spell(id: "spell_willpower_infusion", name: "Willpower Infusion", description: "For 5 minutes, passively generate 1 willpower every 10 seconds.", requiredLevel: 8, runeCost: 3, effect: .willpowerGeneration(1)),
            Spell(id: "spell_bargain_hunter", name: "Bargain Hunter", description: "For 15 minutes, all shop and upgrade costs are reduced by 5%.", requiredLevel: 12, runeCost: 5, effect: .reducedUpgradeCost(0.05)),
            Spell(id: "spell_guild_inspiration", name: "Guild Inspiration", description: "For 10 minutes, all Guild XP gains are increased by 20%.", requiredLevel: 15, runeCost: 6, effect: .guildXpBoost(0.20)),
            Spell(id: "spell_verdant_growth", name: "Verdant Growth", description: "For 15 minutes, plant growth speed is increased by 50%.", requiredLevel: 9, runeCost: 3, effect: .plantGrowthSpeed(0.50))
        ]
    }

    static func createAllStatueTemplates() -> [StatueTemplate] {
        return [
            StatueTemplate(
                id: UUID(),
                name: "Statue of the Unwavering Hero",
                statueDescription: "A monument to sheer determination. Completing it grants a permanent boost to all XP gains.",
                requiredWillpower: 1000,
                reward: .xpBoost
            ),
            StatueTemplate(
                id: UUID(),
                name: "Statue of the Tireless Guardian",
                statueDescription: "A symbol of endless fortitude. Its completion unlocks a new daily quest slot.",
                requiredWillpower: 5000,
                reward: .newDailyQuest
            ),
            StatueTemplate(
                id: UUID(),
                name: "Statue of the Timeless Scholar",
                statueDescription: "A tribute to eternal knowledge. It makes all positive buffs last longer.",
                requiredWillpower: 10000,
                reward: .buffDurationIncrease
            )
        ]
    }

    static func createAllQuestTemplates() -> [QuestTemplate] {
        return [
            QuestTemplate(
                id: UUID(),
                title: "The First Step",
                questDescription: "Begin your journey by completing a single Strength task.",
                type: .milestone(category: .strength, count: 1),
                rewards: [.currency(50), .experienceBurst(skill: .strength, amount: 25)]
            ),
            QuestTemplate(
                id: UUID(),
                title: "A Studious Mind",
                questDescription: "Knowledge is power. Complete 3 Mind tasks.",
                type: .milestone(category: .mind, count: 3),
                rewards: [.currency(100), .experienceBurst(skill: .mind, amount: 75)]
            ),
            QuestTemplate(
                id: UUID(),
                title: "Joyful Beginnings",
                questDescription: "Spread a little happiness by completing 3 Joy tasks.",
                type: .milestone(category: .joy, count: 3),
                rewards: [.item(id: "seed_serenity", quantity: 2)]
            ),
            QuestTemplate(
                id: UUID(),
                title: "The Consistent Hero",
                questDescription: "Form a habit by completing a Strength task for 3 days in a row.",
                type: .streak(category: .strength, days: 3),
                rewards: [.item(id: "seed_discipline", quantity: 1), .runes(1)]
            ),
            QuestTemplate(
                id: UUID(),
                title: "Holistic Development",
                questDescription: "Show your versatility by completing one task from Strength, Mind, and Joy.",
                type: .exploration(categories: [.strength, .mind, .joy]),
                rewards: [.experienceBurst(skill: .vitality, amount: 300), .item(id: "item_ancient_key", quantity: 1)]
            )
        ]
    }

    static func createAllEquipment() -> [Item] {
        return [
            // Head
            Item(id: "equip_leather_cowl", name: "Leather Cowl", description: "A simple leather cowl.", itemType: .equippable, rarity: .common, icon: "person.fill", plantableType: nil, consumableEffect: nil, growTime: nil, harvestReward: nil, slot: .head, bonuses: [EquipmentBonus(stat: .resilience, value: 1)]),
            Item(id: "equip_iron_helmet", name: "Iron Helmet", description: "A sturdy iron helmet.", itemType: .equippable, rarity: .rare, icon: "person.fill", plantableType: nil, consumableEffect: nil, growTime: nil, harvestReward: nil, slot: .head, bonuses: [EquipmentBonus(stat: .resilience, value: 3)]),

            // Chest
            Item(id: "equip_simple_robe", name: "Simple Robe", description: "A simple cloth robe.", itemType: .equippable, rarity: .common, icon: "person.fill", plantableType: nil, consumableEffect: nil, growTime: nil, harvestReward: nil, slot: .chest, bonuses: [EquipmentBonus(stat: .mindfulness, value: 1)]),
            Item(id: "equip_scholars_robe", name: "Scholar's Robe", description: "A robe worn by scholars.", itemType: .equippable, rarity: .rare, icon: "person.fill", plantableType: nil, consumableEffect: nil, growTime: nil, harvestReward: nil, slot: .chest, bonuses: [EquipmentBonus(stat: .intellect, value: 3)]),

            // Hands
            Item(id: "equip_leather_gloves", name: "Leather Gloves", description: "A pair of simple leather gloves.", itemType: .equippable, rarity: .common, icon: "person.fill", plantableType: nil, consumableEffect: nil, growTime: nil, harvestReward: nil, slot: .hands, bonuses: [EquipmentBonus(stat: .creativity, value: 1)]),
            Item(id: "equip_gauntlets_of_strength", name: "Gauntlets of Strength", description: "Gauntlets that imbue the wearer with strength.", itemType: .equippable, rarity: .epic, icon: "person.fill", plantableType: nil, consumableEffect: nil, growTime: nil, harvestReward: nil, slot: .hands, bonuses: [EquipmentBonus(stat: .discipline, value: 5)]),

            // Tool
            Item(id: "equip_rusty_axe", name: "Rusty Axe", description: "A rusty old axe.", itemType: .equippable, rarity: .common, icon: "hammer.fill", plantableType: nil, consumableEffect: nil, growTime: nil, harvestReward: nil, slot: .tool, bonuses: [EquipmentBonus(stat: .discipline, value: 1)]),
            Item(id: "equip_masterwork_pickaxe", name: "Masterwork Pickaxe", description: "A pickaxe of exceptional quality.", itemType: .equippable, rarity: .epic, icon: "hammer.fill", plantableType: nil, consumableEffect: nil, growTime: nil, harvestReward: nil, slot: .tool, bonuses: [EquipmentBonus(stat: .discipline, value: 10)])
        ]
    }

    static func createAllItems() -> [Item] {
        return [
            // --- NEW: Key Item ---
            Item(id: "item_ancient_key", name: "Ancient Key", description: "A heavy, ornate key that hums with a faint energy. It seems destined for a special lock.", itemType: .key, rarity: .epic, icon: "key.fill", plantableType: nil, consumableEffect: nil, growTime: nil, harvestReward: nil, slot: nil, bonuses: nil),

            // --- Potions (Consumables) ---
            Item(id: "item_potion_vigor", name: "Potion of Vigor", description: "A bubbling green liquid that grants a quick burst of energy.", itemType: .consumable, rarity: .common, icon: "testtube.2", plantableType: nil, consumableEffect: .experienceBurst(skill: .discipline, amount: 50), growTime: nil, harvestReward: nil, slot: nil, bonuses: nil),
            Item(id: "item_elixir_strength", name: "Elixir of Strength", description: "A thick, red potion that courses through your veins with power.", itemType: .consumable, rarity: .rare, icon: "testtube.2", plantableType: nil, consumableEffect: .experienceBurst(skill: .discipline, amount: 150), growTime: nil, harvestReward: nil, slot: nil, bonuses: nil),

            // --- Scrolls (Consumables) ---
            Item(id: "item_scroll_fortune", name: "Scroll of Fortune", description: "This scroll glitters with luck, increasing your chances of finding treasure.", itemType: .consumable, rarity: .rare, icon: "scroll.fill", plantableType: nil, consumableEffect: .refreshRandomTask, growTime: nil, harvestReward: nil, slot: nil, bonuses: nil),

            // --- Crafting Materials ---
            Item(id: "material_sunstone_shard", name: "Sunstone Shard", description: "A fragment that glows with the warmth of the sun.", itemType: .material, rarity: .rare, icon: "triangle.fill", plantableType: nil, consumableEffect: nil, growTime: nil, harvestReward: nil, slot: nil, bonuses: nil),
            Item(id: "material_joyful_ember", name: "Joyful Ember", description: "A small, warm ember that crackles with happiness.", itemType: .material, rarity: .common, icon: "flame.fill", plantableType: nil, consumableEffect: nil, growTime: nil, harvestReward: nil, slot: nil, bonuses: nil),

            // --- Habit Seeds ---
            Item(id: "seed_discipline", name: "Seed of Discipline", description: "Consistency in strength builds a foundation of discipline.", itemType: .plantable, rarity: .rare, icon: "flame.fill", plantableType: .habitSeed, consumableEffect: nil, growTime: 7200, harvestReward: .experienceBurst(skill: .strength, amount: 250), slot: nil, bonuses: nil),
            Item(id: "seed_clarity", name: "Seed of Clarity", description: "A focused mind can see through any illusion.", itemType: .plantable, rarity: .rare, icon: "brain.head.profile", plantableType: .habitSeed, consumableEffect: nil, growTime: 7200, harvestReward: .item(id: "material_essence", quantity: 1), slot: nil, bonuses: nil),
            Item(id: "seed_vigor", name: "Seed of Vigor", description: "Caring for the body yields boundless energy.", itemType: .plantable, rarity: .common, icon: "heart.fill", plantableType: .habitSeed, consumableEffect: nil, growTime: 3600, harvestReward: .experienceBurst(skill: .vitality, amount: 100), slot: nil, bonuses: nil),
            Item(id: "seed_serenity", name: "Seed of Serenity", description: "Joy cultivated daily blossoms into lasting peace.", itemType: .plantable, rarity: .common, icon: "face.smiling.fill", plantableType: .habitSeed, consumableEffect: nil, growTime: 3600, harvestReward: .experienceBurst(skill: .joy, amount: 200), slot: nil, bonuses: nil),
            Item(id: "seed_insight", name: "Seed of Insight", description: "Awareness of the self reveals hidden truths.", itemType: .plantable, rarity: .rare, icon: "eye.fill", plantableType: .habitSeed, consumableEffect: nil, growTime: 7200, harvestReward: .item(id: "material_dream_shard", quantity: 1), slot: nil, bonuses: nil),
            Item(id: "seed_inspiration", name: "Seed of Inspiration", description: "Moments of flow can spark brilliant ideas.", itemType: .plantable, rarity: .epic, icon: "wind", plantableType: .habitSeed, consumableEffect: nil, growTime: 14400, harvestReward: .currency(500), slot: nil, bonuses: nil),
            Item(id: "seed_prosperity", name: "Seed of Prosperity", description: "Financial diligence leads to future abundance.", itemType: .plantable, rarity: .common, icon: "dollarsign.circle.fill", plantableType: .habitSeed, consumableEffect: nil, growTime: 3600, harvestReward: .currency(500), slot: nil, bonuses: nil),
            Item(id: "seed_order", name: "Seed of Order", description: "Tidying your space also tidies your mind.", itemType: .plantable, rarity: .common, icon: "sparkles.square.filled.on.square", plantableType: .habitSeed, consumableEffect: nil, growTime: 3600, harvestReward: .experienceBurst(skill: .other, amount: 150), slot: nil, bonuses: nil),

            // --- Crops ---
            Item(id: "crop_sunwheat", name: "Sun-Kissed Wheat", description: "Basic wheat that grows quickly.", itemType: .plantable, rarity: .common, icon: "leaf.fill", plantableType: .crop, consumableEffect: nil, growTime: 1800, harvestReward: .item(id: "material_sunwheat_grain", quantity: 3), slot: nil, bonuses: nil),
            Item(id: "crop_glowcap", name: "Glowcap Mushroom", description: "A mushroom that faintly glows.", itemType: .plantable, rarity: .rare, icon: "circle.grid.3x3.fill", plantableType: .crop, consumableEffect: nil, growTime: 5400, harvestReward: .item(id: "material_glowcap_spore", quantity: 2), slot: nil, bonuses: nil),

            // --- Trees ---
            Item(id: "tree_ironwood", name: "Ironwood Sapling", description: "A slow-growing but incredibly resilient tree.", itemType: .plantable, rarity: .epic, icon: "tree.fill", plantableType: .treeSapling, consumableEffect: nil, growTime: 86400, harvestReward: .item(id: "material_ironwood_bark", quantity: 5), slot: nil, bonuses: nil),

            // --- Additional Materials ---
            Item(id: "material_essence", name: "Focused Essence", description: "A crystalline fragment shimmering with pure mental energy.", itemType: .material, rarity: .common, icon: "sparkles", plantableType: nil, consumableEffect: nil, growTime: nil, harvestReward: nil, slot: nil, bonuses: nil),
            Item(id: "material_dream_shard", name: "Dream Shard", description: "A fragment of a forgotten dream, humming with potential.", itemType: .material, rarity: .rare, icon: "moon.stars.fill", plantableType: nil, consumableEffect: nil, growTime: nil, harvestReward: nil, slot: nil, bonuses: nil),
            Item(id: "material_sunwheat_grain", name: "Sun-Kissed Grain", description: "A warm, golden grain of wheat.", itemType: .material, rarity: .common, icon: "leaf.fill", plantableType: nil, consumableEffect: nil, growTime: nil, harvestReward: nil, slot: nil, bonuses: nil),
            Item(id: "material_glowcap_spore", name: "Glowcap Spore", description: "A faintly glowing mushroom spore.", itemType: .material, rarity: .rare, icon: "circle.grid.3x3.fill", plantableType: nil, consumableEffect: nil, growTime: nil, harvestReward: nil, slot: nil, bonuses: nil),
            Item(id: "material_ironwood_bark", name: "Ironwood Bark", description: "Remarkably tough bark from the legendary Ironwood tree.", itemType: .material, rarity: .epic, icon: "tree.fill", plantableType: nil, consumableEffect: nil, growTime: nil, harvestReward: nil, slot: nil, bonuses: nil),

            // --- New Crafting Chain Materials ---
            Item(id: "material_tanned_leather", name: "Tanned Leather", description: "Leather processed by skilled hands, ready for crafting.", itemType: .material, rarity: .common, icon: "scissors", plantableType: nil, consumableEffect: nil, growTime: nil, harvestReward: nil, slot: nil, bonuses: nil),
            Item(id: "material_spun_flax", name: "Spun Flax", description: "Flax fibers spun into thread.", itemType: .material, rarity: .common, icon: "circle", plantableType: nil, consumableEffect: nil, growTime: nil, harvestReward: nil, slot: nil, bonuses: nil),
            Item(id: "material_linen", name: "Linen", description: "Fine linen woven from spun flax.", itemType: .material, rarity: .common, icon: "square", plantableType: nil, consumableEffect: nil, growTime: nil, harvestReward: nil, slot: nil, bonuses: nil)
        ]
    }

    static func createAllExpeditions() -> [Expedition] {
        return [
            // Beginner Expeditions (1 member, short duration)
            Expedition(
                id: "exp_whispering_woods",
                name: "Forage the Whispering Woods",
                description: "A simple journey to gather common materials from the nearby forest.",
                duration: 3600, // 1 hour
                minMembers: 1,
                requiredRoles: [.forager],
                lootTable: ["material_essence": 80, "material_sunwheat_grain": 50],
                xpReward: 50
            ),
            Expedition(
                id: "exp_crystal_caves",
                name: "Explore Crystal Caves",
                description: "A short expedition to gather crystals and minerals.",
                duration: 7200, // 2 hours
                minMembers: 1,
                requiredRoles: [.alchemist],
                lootTable: ["material_dream_shard": 40, "material_sunstone_shard": 20],
                xpReward: 100
            ),
            
            // Intermediate Expeditions (2+ members, medium duration)
            Expedition(
                id: "exp_sunken_ruins",
                name: "Explore the Sunken Ruins",
                description: "A dangerous trek into ancient, waterlogged ruins.",
                duration: 14400, // 4 hours
                minMembers: 2,
                requiredRoles: [.alchemist, .seer],
                lootTable: ["material_dream_shard": 60, "material_sunstone_shard": 30, "item_ancient_key": 1],
                xpReward: 200
            ),
            Expedition(
                id: "exp_ironwood_forest",
                name: "Harvest Ironwood Forest",
                description: "A challenging expedition to gather rare Ironwood materials.",
                duration: 18000, // 5 hours
                minMembers: 2,
                requiredRoles: [.forager, .blacksmith],
                lootTable: ["material_ironwood_bark": 25, "material_essence": 100],
                xpReward: 250
            ),
            Expedition(
                id: "exp_glowcap_grove",
                name: "Gather Glowcap Mushrooms",
                description: "A mystical journey to collect rare glowing mushrooms.",
                duration: 10800, // 3 hours
                minMembers: 2,
                requiredRoles: [.forager, .alchemist],
                lootTable: ["material_glowcap_spore": 40, "material_dream_shard": 30],
                xpReward: 150
            ),
            
            // Advanced Expeditions (3+ members, long duration)
            Expedition(
                id: "exp_ancient_temple",
                name: "Raid Ancient Temple",
                description: "A perilous expedition into a forgotten temple filled with treasures.",
                duration: 28800, // 8 hours
                minMembers: 3,
                requiredRoles: [.knight, .wizard, .cleric],
                lootTable: ["material_sunstone_shard": 50, "material_dream_shard": 80, "item_ancient_key": 2, "item_elixir_strength": 1],
                xpReward: 400
            ),
            Expedition(
                id: "exp_dragon_peak",
                name: "Scale Dragon Peak",
                description: "An epic journey to the highest peak, rumored to hold dragon treasures.",
                duration: 43200, // 12 hours
                minMembers: 4,
                requiredRoles: [.knight, .archer, .wizard, .cleric],
                lootTable: ["material_sunstone_shard": 100, "material_dream_shard": 150, "item_ancient_key": 3, "item_scroll_fortune": 1],
                xpReward: 600
            ),
            
            // Specialized Expeditions
            Expedition(
                id: "exp_garden_harvest",
                name: "Mass Garden Harvest",
                description: "A coordinated effort to harvest all ready plants from the garden.",
                duration: 5400, // 1.5 hours
                minMembers: 2,
                requiredRoles: [.gardener, .forager],
                lootTable: ["material_sunwheat_grain": 100, "material_glowcap_spore": 30, "material_essence": 120],
                xpReward: 120
            ),
            Expedition(
                id: "exp_alchemy_lab",
                name: "Alchemy Laboratory",
                description: "A focused session in the alchemy lab to create powerful potions.",
                duration: 9000, // 2.5 hours
                minMembers: 2,
                requiredRoles: [.alchemist, .seer],
                lootTable: ["item_potion_vigor": 3, "item_elixir_strength": 2, "material_dream_shard": 50],
                xpReward: 180
            ),
            Expedition(
                id: "exp_blacksmith_forge",
                name: "Master Blacksmith Forge",
                description: "A specialized expedition to craft and enhance equipment.",
                duration: 12600, // 3.5 hours
                minMembers: 2,
                requiredRoles: [.blacksmith, .knight],
                lootTable: ["equip_iron_helmet": 1, "equip_scholars_robe": 1, "material_ironwood_bark": 40],
                xpReward: 200
            ),
            
            // Combat Expeditions
            Expedition(
                id: "exp_goblin_raid",
                name: "Goblin Raid",
                description: "A combat expedition to clear goblin infestations.",
                duration: 7200, // 2 hours
                minMembers: 2,
                requiredRoles: [.knight, .archer],
                lootTable: ["material_essence": 60, "item_potion_vigor": 2],
                xpReward: 150
            ),
            Expedition(
                id: "exp_bandit_camp",
                name: "Clear Bandit Camp",
                description: "A dangerous mission to eliminate bandit threats.",
                duration: 10800, // 3 hours
                minMembers: 3,
                requiredRoles: [.knight, .rogue, .wizard],
                lootTable: ["material_sunstone_shard": 40, "item_elixir_strength": 1, "item_scroll_fortune": 1],
                xpReward: 250
            )
        ]
    }
    
    static func getAllExpeditions() -> [Expedition] {
        return createAllExpeditions()
    }
}

