import SwiftUI
import SwiftData
import Combine

// MARK: - Main Habit Garden View
// FIXED: Added 'public' so this view can be accessed from SanctuaryView
public struct HabitGardenView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var user: User
    
    private var plantableItemsInInventory: [InventoryItem] {
        user.inventory?.filter { ItemDatabase.shared.getItem(id: $0.itemID)?.itemType == .plantable } ?? []
    }
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                
                // --- Habit Garden Section ---
                SanctuarySectionView(
                    title: "Habit Garden",
                    itemCount: user.plantedHabitSeeds?.count ?? 0,
                    maxItems: 6,
                    emptyText: "Plant Habit Seeds from your pouch to gain passive bonuses!"
                ) {
                    ForEach(user.plantedHabitSeeds ?? []) { plantedSeed in
                        GardenPlotView(plantedItem: plantedSeed, user: user)
                    }
                }
                
                // --- Alchemist's Greenhouse Section ---
                SanctuarySectionView(
                    title: "Alchemist's Greenhouse",
                    itemCount: user.plantedCrops?.count ?? 0,
                    maxItems: 8,
                    emptyText: "Plant Crop Seeds to grow valuable crafting materials."
                ) {
                    ForEach(user.plantedCrops ?? []) { plantedCrop in
                        GardenPlotView(plantedItem: plantedCrop, user: user)
                    }
                }

                // --- Grove of Elders Section ---
                SanctuarySectionView(
                    title: "Grove of Elders",
                    itemCount: user.plantedTrees?.count ?? 0,
                    maxItems: 3,
                    emptyText: "Plant rare Tree Saplings for immense long-term rewards."
                ) {
                    ForEach(user.plantedTrees ?? []) { plantedTree in
                        GardenPlotView(plantedItem: plantedTree, user: user)
                    }
                }

                // --- Gardening Pouch Section ---
                Section {
                    if plantableItemsInInventory.isEmpty {
                        Text("Complete tasks to find seeds, crops, and saplings.").font(.caption).foregroundColor(.secondary).padding()
                    } else {
                        ForEach(plantableItemsInInventory) { invItem in
                            PlantablePouchItemView(inventoryItem: invItem, user: user)
                        }
                    }
                } header: {
                    Text("Gardening Pouch").font(.title2).bold().padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("My Sanctuary")
    }
}

// MARK: - Reusable Views

struct SanctuarySectionView<Content: View>: View {
    let title: String
    let itemCount: Int
    let maxItems: Int
    let emptyText: String
    @ViewBuilder let content: Content

    var body: some View {
        Section {
            if itemCount == 0 {
                Text(emptyText)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Material.thin)
                    .cornerRadius(10)
                    .padding(.horizontal)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120))], spacing: 16) {
                    content
                }
                .padding(.horizontal)
            }
        } header: {
            Text("\(title) (\(itemCount)/\(maxItems))")
                .font(.title2).bold().padding([.horizontal, .top])
        }
    }
}

struct GardenPlotView: View {
    @Environment(\.modelContext) private var modelContext
    let plantedItem: any PersistentModel
    @Bindable var user: User
    
    @State private var now = Date()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        let item: Item?
        let plantedAt: Date?
        
        if let seed = plantedItem as? PlantedHabitSeed {
            item = seed.seed
            plantedAt = seed.plantedAt
        } else if let crop = plantedItem as? PlantedCrop {
            item = crop.crop
            plantedAt = crop.plantedAt
        } else if let tree = plantedItem as? PlantedTree {
            item = tree.tree
            plantedAt = tree.plantedAt
        } else {
            item = nil
            plantedAt = nil
        }
        
        guard let validItem = item, let validPlantedAt = plantedAt, let growTime = validItem.growTime else {
            return AnyView(Text("Invalid Item"))
        }
        
        let timePassed = now.timeIntervalSince(validPlantedAt)
        let progress = min(timePassed / growTime, 1.0)
        let isReady = progress >= 1.0

        return AnyView(
            VStack(spacing: 8) {
                ZStack {
                    Circle().fill(rarityColor(for: validItem.rarity).opacity(0.2)).frame(width: 70, height: 70)
                    Image(systemName: validItem.icon).font(.largeTitle).foregroundColor(rarityColor(for: validItem.rarity))
                        .opacity(isReady ? 1.0 : 0.5 + (progress * 0.5))
                    if isReady { Image(systemName: "sparkles").foregroundColor(.yellow) }
                }
                Text(validItem.name).font(.caption).bold().lineLimit(2).multilineTextAlignment(.center)
                
                if isReady {
                    Button("Harvest") {
                        SanctuaryManager.shared.harvest(plantedItem: plantedItem, for: user, context: modelContext)
                    }
                    .buttonStyle(.borderedProminent).tint(.green).font(.caption)
                } else {
                    ProgressView(value: progress)
                    Text(timeRemaining(until: validPlantedAt.addingTimeInterval(growTime)))
                        .font(.caption2).foregroundColor(.secondary)
                }
            }
            .padding().background(Material.regular).cornerRadius(15)
            .onReceive(timer) { newDate in self.now = newDate }
        )
    }
    
    private func timeRemaining(until date: Date) -> String {
        let remaining = date.timeIntervalSince(now)
        if remaining <= 0 { return "Ready!" }
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: remaining) ?? "..."
    }
    
    private func rarityColor(for rarity: Rarity) -> Color {
        switch rarity {
        case .common: return .green
        case .rare: return .blue
        case .epic: return .purple
        case .legendary: return .orange
        }
    }
}

struct PlantablePouchItemView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var inventoryItem: InventoryItem
    @Bindable var user: User
    
    var body: some View {
        if let item = ItemDatabase.shared.getItem(id: inventoryItem.itemID) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: item.icon).font(.title).foregroundColor(rarityColor(for: item.rarity)).frame(width: 40)
                    VStack(alignment: .leading) {
                        Text("\(item.name) (x\(inventoryItem.quantity))").bold()
                        Text(item.description).font(.caption2).italic().foregroundColor(.secondary)
                    }
                    Spacer()
                }
                
                RewardDescriptionView(reward: item.harvestReward)
                
                HStack {
                    Button("Plant") {
                        SanctuaryManager.shared.plantItem(itemID: item.id, for: user, context: modelContext)
                    }
                    .buttonStyle(.borderedProminent).tint(.green)
                    
                    Spacer()
                    Text("Grow time: \(formattedGrowTime(item.growTime))")
                        .font(.caption).foregroundColor(.secondary)
                }
            }
            .padding().background(Material.regular).cornerRadius(15).padding(.horizontal)
        }
    }
    
    private func rarityColor(for rarity: Rarity) -> Color {
        switch rarity {
        case .common: return .green
        case .rare: return .blue
        case .epic: return .purple
        case .legendary: return .orange
        }
    }
    
    private func formattedGrowTime(_ time: TimeInterval?) -> String {
        guard let time = time else { return "N/A" }
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .short
        return formatter.string(from: time) ?? "-"
    }
}

struct RewardDescriptionView: View {
    let reward: Item.HarvestReward?
    var body: some View {
        switch reward {
        case .currency(let amt): Text("Harvest yields \(amt) Gold").font(.caption).foregroundColor(.yellow)
        case .item(let id, let qty): Text("Harvest yields x\(qty) \(ItemDatabase.shared.getItem(id: id)?.name ?? id)").font(.caption)
        case .experienceBurst(let skill, let amt): Text("Harvest yields +\(amt) \(skill.rawValue.capitalized) XP").font(.caption)
        case .none: EmptyView()
        }
    }
}

struct GuildHallView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var user: User
    @State private var timer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()

    private var guild: Guild? { user.guild }
    private var members: [GuildMember] { user.guildMembers ?? [] }
    private var activeExpeditions: [ActiveExpedition] { user.activeExpeditions ?? [] }
    private var activeBounties: [GuildBounty] { (user.guildBounties ?? []).filter { $0.isActive } }

    private var plantedCounts: (seeds: Int, crops: Int, trees: Int) {
        (user.plantedHabitSeeds?.count ?? 0, user.plantedCrops?.count ?? 0, user.plantedTrees?.count ?? 0)
    }

    private var readyToHarvestCount: Int {
        let now = Date()
        let seedReady = (user.plantedHabitSeeds ?? []).filter { p in if let s = p.seed, let t = s.growTime { return p.plantedAt.addingTimeInterval(t) <= now } else { return false } }.count
        let cropReady = (user.plantedCrops ?? []).filter { p in if let s = p.crop, let t = s.growTime { return p.plantedAt.addingTimeInterval(t) <= now } else { return false } }.count
        let treeReady = (user.plantedTrees ?? []).filter { p in if let s = p.tree, let t = s.growTime { return p.plantedAt.addingTimeInterval(t) <= now } else { return false } }.count
        return seedReady + cropReady + treeReady
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                Text("Guild Hall").font(.largeTitle).bold().padding(.horizontal)
                GuildHeaderView(guild: guild, user: user)

                // Quick Stats Grid
                dashboardGrid

                // Automations
                automationSection

                // Members
                Section {
                    Text("Your Guild Members").font(.title2).bold().padding(.horizontal)
                    if members.isEmpty {
                        Text("No members yet. Hire someone from the Guild Master!")
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                    } else {
                        ForEach(members) { member in
                            GuildMemberRowView(member: member, user: user)
                        }
                    }
                }

                // Hiring
                Section {
                    Text("Hire More").font(.title2).bold().padding(.horizontal)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 16)], spacing: 16) {
                        ForEach(GuildMember.Role.allCases, id: \.self) { role in
                            HireableMemberCardView(role: role, user: user)
                        }
                    }.padding(.top, 8)
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Guild Hall")
        .onAppear {
            if user.guild == nil { GuildManager.shared.initializeGuild(for: user, context: modelContext) }
        }
        .onReceive(timer) { _ in
            GuildManager.shared.checkCompletedExpeditions(for: user, context: modelContext)
            GuildManager.shared.processAutomations(for: user, context: modelContext)
        }
    }

    private var dashboardGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 16)], spacing: 16) {
            statCard(title: "Members", value: "\(members.count)", icon: "person.3.fill", tint: .blue)
            statCard(title: "Expeditions", value: "\(activeExpeditions.count)", icon: "map.fill", tint: .green)
            statCard(title: "Bounties", value: "\(activeBounties.count)", icon: "scroll.fill", tint: .orange)
            statCard(title: "Garden Ready", value: "\(readyToHarvestCount)", icon: "leaf.fill", tint: .green)
            let eps = String(format: "%.2f/s", IdleGameManager.shared.totalEchoesPerSecond(for: user))
            statCard(title: "Echoes", value: eps, icon: "flame.fill", tint: .purple)
        }
        .padding(.horizontal)
    }

    private func statCard(title: String, value: String, icon: String, tint: Color) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: icon).foregroundColor(.white).padding(10).background(tint.opacity(0.6)).clipShape(RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading) {
                Text(title).font(.caption).foregroundColor(.secondary)
                Text(value).font(.headline)
            }
            Spacer()
        }
        .padding()
        .background(Material.regular)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var automationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Worker Automations").font(.title2).bold().padding(.horizontal)
            VStack(spacing: 12) {
                // Gardener Controls
                automationRow(icon: "leaf.fill", color: .green) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Gardeners").font(.headline)
                        Toggle("Auto-harvest ready plants", isOn: Binding(get: { user.guildAutomation.autoHarvestGarden }, set: { v in var s = user.guildAutomation; s.autoHarvestGarden = v; user.guildAutomation = s }))
                        Toggle("Auto-plant Habit Seeds", isOn: Binding(get: { user.guildAutomation.autoPlantHabitSeeds }, set: { v in var s = user.guildAutomation; s.autoPlantHabitSeeds = v; user.guildAutomation = s }))
                        HStack {
                            Text("Maintain plots: \(user.guildAutomation.gardenerMaintainPlots)")
                            Spacer()
                            Stepper("", value: Binding(get: { user.guildAutomation.gardenerMaintainPlots }, set: { v in var s = user.guildAutomation; s.gardenerMaintainPlots = max(0, min(6, v)); user.guildAutomation = s }))
                                .labelsHidden()
                        }
                        if user.guildAutomation.autoPlantHabitSeeds {
                            seedPicker
                        }
                    }
                }

                // Forager Controls
                automationRow(icon: "bag.fill", color: .brown) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Foragers").font(.headline)
                        Toggle("Gather materials for the Altar", isOn: Binding(get: { user.guildAutomation.foragerGatherForAltar }, set: { v in var s = user.guildAutomation; s.foragerGatherForAltar = v; user.guildAutomation = s }))
                        Text("Items are periodically added to your inventory based on Forager levels.").font(.caption).foregroundColor(.secondary)
                    }
                }

                // Seer Controls
                automationRow(icon: "eye.fill", color: .purple) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Seers").font(.headline)
                        Toggle("Attune the Altar (boost Echoes)", isOn: Binding(get: { user.guildAutomation.seerAttuneAltar }, set: { v in var s = user.guildAutomation; s.seerAttuneAltar = v; user.guildAutomation = s }))
                        Text("When enabled, Seers increase your Echo generation.").font(.caption).foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    private var seedPicker: some View {
        let seedOptions: [Item] = (user.inventory ?? [])
            .compactMap { ItemDatabase.shared.getItem(id: $0.itemID) }
            .filter { $0.plantableType == .habitSeed }
        return Group {
            if !seedOptions.isEmpty {
                HStack {
                    Text("Preferred seed:")
                    Spacer()
                    Menu(content: {
                        Button("Any available") { var s = user.guildAutomation; s.preferredHabitSeedID = nil; user.guildAutomation = s }
                        ForEach(seedOptions, id: \.id) { item in
                            Button(item.name) { var s = user.guildAutomation; s.preferredHabitSeedID = item.id; user.guildAutomation = s }
                        }
                    }, label: {
                        let selectedName = seedOptions.first(where: { $0.id == user.guildAutomation.preferredHabitSeedID })?.name ?? "Any"
                        HStack { Text(selectedName); Image(systemName: "chevron.down").font(.caption) }
                    })
                }
            }
        }
    }

    private func automationRow<Content: View>(icon: String, color: Color, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).foregroundColor(.white).padding(10).background(color.opacity(0.7)).clipShape(RoundedRectangle(cornerRadius: 8))
            content()
            Spacer()
        }
        .padding()
        .background(Material.regular)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct GuildMemberRowView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var member: GuildMember
    @Bindable var user: User
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "person.fill.badge.plus")
                Text("\(member.name) • \(member.role.rawValue) • Lv \(member.level)").bold()
                Spacer()
                Text("Gold: \(user.gold)").font(.caption).foregroundColor(.yellow)
            }
            
            Text(member.roleDescription).font(.caption).italic()
            
            ProgressView(value: Double(member.xp % 100), total: 100)
                .padding(.vertical, 4)

            if member.isOnExpedition {
                Text("On Expedition").font(.caption).foregroundColor(.blue).bold()
            } else {
                Button("Upgrade (\(member.upgradeCost()) G)") {
                    GuildManager.shared.upgradeGuildMember(member: member, user: user, context: modelContext)
                }
                .buttonStyle(.bordered).tint(.blue)
                .disabled(user.gold < member.upgradeCost())
            }
        }
        .padding().background(Material.regular).cornerRadius(15).padding(.horizontal)
    }
}

struct HireableMemberCardView: View {
    @Environment(\.modelContext) private var modelContext
    let role: GuildMember.Role
    @Bindable var user: User
    
    var body: some View {
        let cost = 250
        let tempMember = GuildMember(name: "", role: role, owner: nil)
        
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Hire a \(role.rawValue)").font(.headline.bold())
                Spacer()
                Text("Gold: \(user.gold)").font(.caption).foregroundColor(.yellow)
            }
            Text(tempMember.roleDescription).font(.caption).italic().foregroundColor(.secondary)
            
            Button("Hire (\(cost) G)") {
                _ = GuildManager.shared.hireGuildMember(role: role, for: user, context: modelContext)
                // Haptic feedback removed for macOS compatibility
            }
            .buttonStyle(.borderedProminent).tint(.green)
            .disabled(user.gold < cost)
        }
        .padding().background(Material.regular).cornerRadius(15).padding(.horizontal)
    }
}

struct ExpeditionCardView: View {
    let expedition: Expedition
    var onPrepare: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(expedition.name).font(.headline.bold())
            Text(expedition.description).font(.caption).italic()
            Button("Prepare Party", action: onPrepare)
                .buttonStyle(.borderedProminent).tint(.blue)
        }
        .padding().background(Material.regular).cornerRadius(15).padding(.horizontal)
    }
}

struct ActiveExpeditionCardView: View {
    @Bindable var activeExpedition: ActiveExpedition
    
    @State private var now = Date()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(activeExpedition.expedition?.name ?? "Expedition").font(.headline.bold())
            Text("Ends in \(timeRemaining(until: activeExpedition.endTime))").font(.caption).foregroundColor(.secondary)
            ProgressView(value: progress)
        }
        .padding().background(Material.regular).cornerRadius(15).padding(.horizontal)
        .onReceive(timer) { _ in }
    }
    
    private var progress: Double {
        let total = activeExpedition.expedition?.duration ?? 1
        let elapsed = Date().timeIntervalSince(activeExpedition.startTime)
        return min(max(elapsed / total, 0), 1)
    }
    
    private func timeRemaining(until date: Date) -> String {
        let remaining = date.timeIntervalSince(Date())
        if remaining <= 0 { return "Done" }
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: remaining) ?? "..."
    }
}
