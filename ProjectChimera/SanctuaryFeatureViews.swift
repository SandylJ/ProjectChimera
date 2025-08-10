import SwiftUI
import SwiftData
import Combine

fileprivate let maxHabitPlotsCap = 24

// MARK: - Main Habit Garden View
// FIXED: Added 'public' so this view can be accessed from SanctuaryView
public struct HabitGardenView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var user: User
    @State private var activeTab: GardenTab = .dashboard
    @State private var now: Date = Date()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    private enum GardenTab: String, CaseIterable { case dashboard, garden, greenhouse, grove, pouch, workers }
    
    private var plantableItemsInInventory: [InventoryItem] {
        user.inventory?.filter { ItemDatabase.shared.getItem(id: $0.itemID)?.itemType == .plantable } ?? []
    }

    // Dashboard metrics
    private var gardenersCount: Int { (user.guildMembers ?? []).filter { $0.role == .gardener }.count }
    private var foragersCount: Int { (user.guildMembers ?? []).filter { $0.role == .forager }.count }
    private var maxHabitPlots: Int { min(maxHabitPlotsCap, max(6, user.guildAutomation.gardenerMaintainPlots)) }
    private var readyToHarvestCount: Int {
        let now = Date()
        let seedReady = (user.plantedHabitSeeds ?? []).filter { p in if let s = p.seed, let t = s.growTime { return p.plantedAt.addingTimeInterval(t) <= now } else { return false } }.count
        let cropReady = (user.plantedCrops ?? []).filter { p in if let s = p.crop, let t = s.growTime { return p.plantedAt.addingTimeInterval(t) <= now } else { return false } }.count
        let treeReady = (user.plantedTrees ?? []).filter { p in if let s = p.tree, let t = s.growTime { return p.plantedAt.addingTimeInterval(t) <= now } else { return false } }.count
        return seedReady + cropReady + treeReady
    }
    private var foragerProgress: Double { min(user.automationProgressForager, 1.0) }
    
    public var body: some View {
        ZStack {
            GameTheme.bgGradient.ignoresSafeArea()
            SparkleField()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 14) {
                            headerBar
                            metricsDeck
                            if readyToHarvestCount > 0 { quickActionsBar }
                            tabsBar
                            Group { tabContent }
                                .padding(.horizontal, 14)
                                .padding(.bottom, 4)
                        }
                        .padding(14)
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 18)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("Habit Garden")
        .safeAreaInset(edge: .top) {
            GameHUD(
                coins: user.gold,
                gems: user.runes,
                keys: user.inventory?.filter { ItemDatabase.shared.getItem(id: $0.itemID)?.itemType == .key }.reduce(0) { $0 + $1.quantity } ?? 0
            )
            .background(Color.clear)
        }
        .onReceive(timer) { date in now = date }
    }

    // MARK: - Header & Tabs
    private var headerBar: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(LinearGradient(colors: [.green.opacity(0.35), .mint.opacity(0.35)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 44, height: 44)
                    .shadow(color: .green.opacity(0.25), radius: 10, x: 0, y: 6)
                Image(systemName: "leaf.fill").font(.title2.weight(.bold)).foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("The Habit Garden").font(.title.bold()).foregroundStyle(GameTheme.textPrimary)
                Text("Tend seeds, grow rewards, empower your journey").font(.footnote).foregroundStyle(GameTheme.textSecondary)
            }
            Spacer()
            labelChip(text: "Ready: \(readyToHarvestCount)", icon: "sparkles", tint: .green)
        }
    }

    private var tabsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(GardenTab.allCases, id: \.self) { tab in
                    let isSel = activeTab == tab
                    Button(action: { withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) { activeTab = tab } }) {
                        HStack(spacing: 6) {
                            Image(systemName: icon(for: tab))
                            Text(title(for: tab))
                        }
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(isSel ? Color.white.opacity(0.15) : Color.white.opacity(0.08))
                        .overlay(Capsule().stroke(Color.white.opacity(isSel ? 0.6 : 0.25), lineWidth: isSel ? 2 : 1))
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func icon(for tab: GardenTab) -> String {
        switch tab {
        case .dashboard: return "speedometer"
        case .garden: return "leaf.fill"
        case .greenhouse: return "sprinkler.and.droplets"
        case .grove: return "tree.fill"
        case .pouch: return "bag.fill"
        case .workers: return "person.3.fill"
        }
    }
    private func title(for tab: GardenTab) -> String {
        switch tab {
        case .dashboard: return "Dashboard"
        case .garden: return "Garden"
        case .greenhouse: return "Greenhouse"
        case .grove: return "Grove"
        case .pouch: return "Pouch"
        case .workers: return "Workers"
        }
    }

    // MARK: - Deck & Actions
    private var metricsDeck: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                metricCard(title: "Plots", value: "\(user.plantedHabitSeeds?.count ?? 0)/\(maxHabitPlots)", icon: "square.grid.2x2.fill", tint: .green)
                metricCard(title: "Ready", value: "\(readyToHarvestCount)", icon: "leaf.fill", tint: .mint)
            }
            HStack(spacing: 12) {
                metricCard(title: "Gardeners", value: "\(gardenersCount)", icon: "person.fill", tint: .green)
                metricCard(title: "Foragers", value: "\(foragersCount)", icon: "bag.fill", tint: .brown)
                metricCard(title: "Gold", value: "\(user.gold)", icon: "creditcard.fill", tint: .yellow)
            }
            if foragersCount > 0 { foragerRow }
        }
    }

    private func metricCard(title: String, value: String, icon: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack { Image(systemName: icon).foregroundStyle(tint); Spacer() }
            Text(value).font(.system(.title3, design: .rounded).bold()).foregroundStyle(GameTheme.textPrimary)
            Text(title).font(.caption).foregroundStyle(GameTheme.textSecondary)
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(tint.opacity(0.35), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: tint.opacity(0.15), radius: 8, x: 0, y: 4)
    }

    private var foragerRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "bag.fill").foregroundStyle(.brown)
            VStack(alignment: .leading, spacing: 6) {
                Text("Foragers").font(.headline).foregroundStyle(GameTheme.textPrimary)
                ProgressView(value: foragerProgress)
                    .progressViewStyle(LinearProgressViewStyle(tint: .brown))
                Text("Progress to next find").font(.caption).foregroundStyle(GameTheme.textSecondary)
            }
            Spacer()
        }
        .padding(12)
        .background(GameTheme.panelFill, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(GameTheme.panelStroke))
    }

    private var quickActionsBar: some View {
        HStack(spacing: 10) {
            Button {
                harvestAllReady()
            } label: {
                HStack(spacing: 8) { Image(systemName: "sparkles"); Text("Harvest All (\(readyToHarvestCount))") }
            }
            .buttonStyle(GlowButtonStyle(gradient: LinearGradient(colors: [.green, .mint], startPoint: .topLeading, endPoint: .bottomTrailing), animatedSheen: false))
            Spacer()
            Button("Kickstart Garden") { kickstartGarden() }
                .buttonStyle(GlowButtonStyle(gradient: GameTheme.infoGradient, animatedSheen: false))
        }
    }

    // MARK: - Tab Content
    @ViewBuilder private var tabContent: some View {
        switch activeTab {
        case .dashboard:
            VStack(alignment: .leading, spacing: 18) {
                sectionHeader("Overview")
                gardenGrid(items: user.plantedHabitSeeds ?? [])
                if !(user.plantedCrops ?? []).isEmpty { sectionHeader("Greenhouse"); gardenGrid(items: user.plantedCrops ?? []) }
                if !(user.plantedTrees ?? []).isEmpty { sectionHeader("Grove of Elders"); gardenGrid(items: user.plantedTrees ?? []) }
            }
        case .garden:
            VStack(alignment: .leading, spacing: 12) { sectionHeader("Habit Garden (\(user.plantedHabitSeeds?.count ?? 0)/\(maxHabitPlots))"); gardenGrid(items: user.plantedHabitSeeds ?? []) }
        case .greenhouse:
            VStack(alignment: .leading, spacing: 12) { sectionHeader("Alchemist's Greenhouse"); gardenGrid(items: user.plantedCrops ?? []) }
        case .grove:
            VStack(alignment: .leading, spacing: 12) { sectionHeader("Grove of Elders"); gardenGrid(items: user.plantedTrees ?? []) }
        case .pouch:
            pouchList
        case .workers:
            workersPanel
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        HStack { Text(title).font(.title3.weight(.heavy)).foregroundStyle(GameTheme.textPrimary); Spacer() }
    }

    private func gardenGrid<T: PersistentModel>(items: [T]) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
            ForEach(items) { anyItem in
                plotCardSpectacular(plantedItem: anyItem)
            }
        }
    }

    // MARK: - Plot Card (Spectacular)
    private func plotCardSpectacular(plantedItem: any PersistentModel) -> some View {
        let item: Item? = {
            if let seed = plantedItem as? PlantedHabitSeed { return seed.seed }
            if let crop = plantedItem as? PlantedCrop { return crop.crop }
            if let tree = plantedItem as? PlantedTree { return tree.tree }
            return nil
        }()
        let plantedAt: Date? = {
            if let seed = plantedItem as? PlantedHabitSeed { return seed.plantedAt }
            if let crop = plantedItem as? PlantedCrop { return crop.plantedAt }
            if let tree = plantedItem as? PlantedTree { return tree.plantedAt }
            return nil
        }()
        guard let validItem = item, let validPlantedAt = plantedAt, let growTime = validItem.growTime else {
            return AnyView(EmptyView())
        }
        let elapsed = now.timeIntervalSince(validPlantedAt)
        let progress = min(max(elapsed / growTime, 0), 1)
        let isReady = progress >= 1.0
        return AnyView(
            VStack(alignment: .center, spacing: 10) {
                ZStack {
                    Circle().stroke(Color.white.opacity(0.15), lineWidth: 10)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(AngularGradient(gradient: Gradient(colors: [.green, .mint, .cyan, .green]), center: .center), style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Image(systemName: validItem.icon)
                        .font(.title)
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.4), radius: 6, x: 0, y: 3)
                    if isReady {
                        Image(systemName: "sparkles").foregroundStyle(.yellow).offset(x: 26, y: -26)
                    }
                }
                .frame(width: 96, height: 96)
                Text(validItem.name).font(.subheadline.weight(.semibold)).foregroundStyle(GameTheme.textPrimary).lineLimit(2).multilineTextAlignment(.center)
                if isReady {
                    Button {
                        SanctuaryManager.shared.harvest(plantedItem: plantedItem, for: user, context: modelContext)
                    } label: {
                        HStack(spacing: 6) { Image(systemName: "scissors"); Text("Harvest") }
                    }
                    .buttonStyle(GlowButtonStyle(gradient: LinearGradient(colors: [.green, .mint], startPoint: .topLeading, endPoint: .bottomTrailing), animatedSheen: false))
                } else {
                    ProgressView(value: progress)
                        .progressViewStyle(.linear)
                    Text(timeRemaining(until: validPlantedAt.addingTimeInterval(growTime)))
                        .font(.caption2)
                        .foregroundStyle(GameTheme.textSecondary)
                }
            }
            .padding(12)
            .background(GameTheme.panelFill, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(GameTheme.panelStroke))
        )
    }

    private func labelChip(text: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 6) { Image(systemName: icon); Text(text) }
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(tint.opacity(0.15), in: Capsule())
            .overlay(Capsule().stroke(tint.opacity(0.4), lineWidth: 1))
            .foregroundStyle(.white)
    }

    // MARK: - Pouch
    private var pouchList: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Gardening Pouch")
            if plantableItemsInInventory.isEmpty {
                Text("Complete tasks to find seeds, crops, and saplings.")
                    .font(.callout)
                    .foregroundStyle(GameTheme.textSecondary)
            } else {
                ForEach(plantableItemsInInventory) { invItem in
                    pouchItemCard(invItem)
                }
            }
        }
    }

    private func pouchItemCard(_ invItem: InventoryItem) -> some View {
        guard let item = ItemDatabase.shared.getItem(id: invItem.itemID) else { return AnyView(EmptyView()) }
        return AnyView(
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    ZStack {
                        Circle().fill(Color.white.opacity(0.08)).frame(width: 44, height: 44)
                        Image(systemName: item.icon).foregroundStyle(.white)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(item.name)  x\(invItem.quantity)").font(.headline).foregroundStyle(GameTheme.textPrimary)
                        Text(item.description).font(.caption).foregroundStyle(GameTheme.textSecondary)
                    }
                    Spacer()
                }
                HStack(spacing: 10) {
                    Button {
                        SanctuaryManager.shared.plantItem(itemID: item.id, for: user, context: modelContext)
                    } label: { HStack(spacing: 6) { Image(systemName: "leaf.fill"); Text("Plant") } }
                    .buttonStyle(GlowButtonStyle(gradient: LinearGradient(colors: [.green, .mint], startPoint: .topLeading, endPoint: .bottomTrailing), animatedSheen: false))
                    Spacer()
                    Text("Grow: \(formattedGrowTime(item.growTime))")
                        .font(.caption)
                        .foregroundStyle(GameTheme.textSecondary)
                }
            }
            .padding(12)
            .background(GameTheme.panelFill, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(GameTheme.panelStroke))
        )
    }

    // MARK: - Workers Panel
    private var workersPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("Workers & Automation")
            HStack(spacing: 12) {
                HireableMemberCardView(role: .gardener, user: user)
                HireableMemberCardView(role: .forager, user: user)
            }
            .fixedSize(horizontal: false, vertical: true)
            VStack(spacing: 12) {
                automationRow(icon: "leaf.fill", color: .green) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Gardeners").font(.headline)
                        Toggle("Auto-harvest ready plants", isOn: Binding(get: { user.guildAutomation.autoHarvestGarden }, set: { v in var s = user.guildAutomation; s.autoHarvestGarden = v; user.guildAutomation = s }))
                        Toggle("Auto-plant Habit Seeds", isOn: Binding(get: { user.guildAutomation.autoPlantHabitSeeds }, set: { v in var s = user.guildAutomation; s.autoPlantHabitSeeds = v; user.guildAutomation = s }))
                        HStack { Text("Maintain plots: \(user.guildAutomation.gardenerMaintainPlots)"); Spacer(); Stepper("", value: Binding(get: { user.guildAutomation.gardenerMaintainPlots }, set: { v in var s = user.guildAutomation; s.gardenerMaintainPlots = max(0, min(maxHabitPlotsCap, v)); user.guildAutomation = s })).labelsHidden() }
                        if user.guildAutomation.autoPlantHabitSeeds { seedPicker }
                    }
                }
                automationRow(icon: "bag.fill", color: .brown) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Foragers").font(.headline)
                        Toggle("Gather materials for the Altar", isOn: Binding(get: { user.guildAutomation.foragerGatherForAltar }, set: { v in var s = user.guildAutomation; s.foragerGatherForAltar = v; user.guildAutomation = s }))
                        Text("Items are periodically added to your inventory based on Forager levels.").font(.caption).foregroundStyle(GameTheme.textSecondary)
                    }
                }
            }
            let gatherers = (user.guildMembers ?? []).filter { $0.role == .gardener || $0.role == .forager }
            if !gatherers.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(gatherers) { member in
                        GuildMemberRowView(member: member, user: user)
                    }
                }
            }
        }
    }
    
    private func formattedGrowTime(_ time: TimeInterval?) -> String {
        guard let time = time else { return "N/A" }
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .short
        return formatter.string(from: time) ?? "-"
    }
    
    private func timeRemaining(until date: Date) -> String {
        let remaining = date.timeIntervalSince(now)
        if remaining <= 0 { return "Ready!" }
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: remaining) ?? "..."
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

    private func harvestAllReady() {
        let now = Date()
        // Habit Seeds
        for planted in (user.plantedHabitSeeds ?? []) {
            if let seed = planted.seed, let growTime = seed.growTime, planted.plantedAt.addingTimeInterval(growTime) <= now {
                SanctuaryManager.shared.harvest(plantedItem: planted, for: user, context: modelContext)
            }
        }
        // Crops
        for planted in (user.plantedCrops ?? []) {
            if let crop = planted.crop, let growTime = crop.growTime, planted.plantedAt.addingTimeInterval(growTime) <= now {
                SanctuaryManager.shared.harvest(plantedItem: planted, for: user, context: modelContext)
            }
        }
        // Trees
        for planted in (user.plantedTrees ?? []) {
            if let tree = planted.tree, let growTime = tree.growTime, planted.plantedAt.addingTimeInterval(growTime) <= now {
                SanctuaryManager.shared.harvest(plantedItem: planted, for: user, context: modelContext)
            }
        }
    }

    private func kickstartGarden() {
        if user.gold < 600 { user.gold = 600 }
        if !(user.guildMembers ?? []).contains(where: { $0.role == .forager }) {
            _ = GuildManager.shared.hireGuildMember(role: .forager, for: user, context: modelContext)
        }
        if !(user.guildMembers ?? []).contains(where: { $0.role == .gardener }) {
            _ = GuildManager.shared.hireGuildMember(role: .gardener, for: user, context: modelContext)
        }
        func addItem(_ id: String, qty: Int) {
            if let existing = user.inventory?.first(where: { $0.itemID == id }) { existing.quantity += qty }
            else { user.inventory?.append(InventoryItem(itemID: id, quantity: qty, owner: user)) }
        }
        addItem("seed_vigor", qty: 3)
        addItem("seed_serenity", qty: 2)
        addItem("crop_sunwheat", qty: 2)
        let plantIDs = ["seed_vigor", "seed_serenity", "crop_sunwheat"]
        for pid in plantIDs {
            SanctuaryManager.shared.plantItem(itemID: pid, for: user, context: modelContext)
        }
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
    @State private var showMemberList: Bool = false
    @State private var selectedExpedition: Expedition? = nil
    @State private var showingExpeditionDetails: Bool = false

    private var guild: Guild? { user.guild }
    private var members: [GuildMember] { (user.guildMembers ?? []).filter { $0.role.isGathererRole } }
    private var availableGatherers: [GuildMember] { (user.guildMembers ?? []).filter { $0.role.isGathererRole && !$0.isOnExpedition } }
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

                // Quick actions row
                if readyToHarvestCount > 0 {
                    HStack(spacing: 12) {
                        Button("Harvest All Ready (\(readyToHarvestCount))") { harvestAllReady() }
                            .buttonStyle(.borderedProminent).tint(.green)
                        Spacer()
                    }
                    .padding(.horizontal)
                }

                // Live Gathering
                liveGatheringSection

                // Automations
                automationSection

                // Gathering Expeditions Overview
                gatheringExpeditionsSection

                // Bounties Overview (non-combat focused shown here)
                bountiesOverviewSection

                // Members Summary (clean UI)
                Section {
                    HStack {
                        Text("Your Guild Gatherers").font(.title2).bold()
                        Spacer()
                        Button(action: { showMemberList.toggle() }) {
                            HStack(spacing: 6) {
                                Text(showMemberList ? "Hide List" : "Show List")
                                Image(systemName: showMemberList ? "chevron.up" : "chevron.down")
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.horizontal)

                    if members.isEmpty {
                        VStack(spacing: 8) {
                            Text("No gatherers yet. Kickstart operations to get going!")
                                .foregroundColor(.secondary)
                            Button("Kickstart Gathering") { quickstartGathering() }
                                .buttonStyle(.borderedProminent).tint(.blue)
                        }
                        .padding(.horizontal)
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 16)], spacing: 16) {
                            statCard(title: "Seeds Planted", value: "\(user.totalSeedsPlantedByGuild + user.totalCropsPlantedByGuild)", icon: "leaf.fill", tint: .green)
                            statCard(title: "Trees Harvested", value: "\(user.totalTreesHarvestedByGuild)", icon: "tree.fill", tint: .green)
                            statCard(title: "Crops Harvested", value: "\(user.totalCropsHarvestedByGuild)", icon: "tray.full.fill", tint: .orange)
                            statCard(title: "Items Found", value: "\(user.totalItemsFoundByGuild)", icon: "bag.fill", tint: .brown)
                        }
                        .padding(.horizontal)

                        if showMemberList {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(members) { member in
                                    GuildMemberRowView(member: member, user: user)
                                }
                            }
                            .transition(.opacity)
                        }
                    }
                }

                // Hiring
                Section {
                    Text("Hire More Gatherers").font(.title2).bold().padding(.horizontal)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 16)], spacing: 16) {
                        ForEach(GuildMember.Role.allCases.filter { $0.isGathererRole }, id: \.self) { role in
                            HireableMemberCardView(role: role, user: user)
                        }
                    }.padding(.top, 8)
                }

                // Claim unclaimed hunt rewards (reuse existing component)
                if user.unclaimedHuntGold > 0 || !user.unclaimedHuntItems.isEmpty {
                    UnclaimedRewardsSection(user: user, modelContext: modelContext)
                        .padding(.horizontal)
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
        .sheet(isPresented: $showingExpeditionDetails) {
            if let expedition = selectedExpedition {
                ExpeditionDetailView(
                    expedition: expedition,
                    availableMembers: availableGatherers,
                    onLaunch: { selectedIDs in
                        GuildManager.shared.launchExpedition(
                            expeditionID: expedition.id,
                            with: Array(selectedIDs),
                            for: user,
                            context: modelContext
                        )
                        showingExpeditionDetails = false
                    }
                )
            }
        }
    }

    private var dashboardGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 16)], spacing: 16) {
            statCard(title: "Gatherers", value: "\(members.count)", icon: "person.3.fill", tint: .blue)
            statCard(title: "Gathering Expeditions", value: "\(activeExpeditions.count)", icon: "map.fill", tint: .green)
            statCard(title: "Bounties", value: "\(activeBounties.count)", icon: "scroll.fill", tint: .orange)
            statCard(title: "Garden Ready", value: "\(readyToHarvestCount)", icon: "leaf.fill", tint: .green)
            let eps = String(format: "%.2f/s", IdleGameManager.shared.totalEchoesPerSecond(for: user))
            statCard(title: "Echoes", value: eps + (user.activeBuffs.keys.contains(where: { if case .echoBoost = $0 { return true } else { return false } }) ? " (+)" : ""), icon: "flame.fill", tint: .purple)
        }
        .padding(.horizontal)
    }

    private var gatheringExpeditionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Gathering Expeditions").font(.title2).bold().padding(.horizontal)
            AvailableExpeditionsGrid(user: user, mode: .gathering) { expedition in
                selectedExpedition = expedition
                showingExpeditionDetails = true
            }
            if !activeExpeditions.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Active Expeditions").font(.headline).padding(.horizontal)
                    ForEach(activeExpeditions) { act in
                        ActiveExpeditionCardView(activeExpedition: act)
                    }
                }
            }
        }
    }

    private var bountiesOverviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Bounties Overview").font(.title2).bold().padding(.horizontal)
            if activeBounties.isEmpty {
                Text("No active bounties.").font(.caption).foregroundColor(.secondary).padding(.horizontal)
            } else {
                VStack(spacing: 12) {
                    ForEach(activeBounties) { bounty in
                        EnhancedBountyCard(bounty: bounty, user: user)
                    }
                }
                .padding(.horizontal)
            }
        }
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
                            Stepper("", value: Binding(get: { user.guildAutomation.gardenerMaintainPlots }, set: { v in var s = user.guildAutomation; s.gardenerMaintainPlots = max(0, min(maxHabitPlotsCap, v)); user.guildAutomation = s }))
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

    private var liveGatheringSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Live Gathering").font(.title2).bold().padding(.horizontal)
            HStack(spacing: 12) {
                // Forager live progress
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "bag.fill").foregroundColor(.brown)
                        Text("Foragers")
                            .font(.headline)
                    }
                    ProgressView(value: min(user.automationProgressForager, 1.0))
                        .progressViewStyle(LinearProgressViewStyle(tint: .brown))
                    Text("Progress to next find")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Material.regular)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                Spacer(minLength: 0)
            }
            .padding(.horizontal)
        }
    }

    private func harvestAllReady() {
        let now = Date()
        // Habit Seeds
        for planted in (user.plantedHabitSeeds ?? []) {
            if let seed = planted.seed, let growTime = seed.growTime, planted.plantedAt.addingTimeInterval(growTime) <= now {
                SanctuaryManager.shared.harvest(plantedItem: planted, for: user, context: modelContext)
            }
        }
        // Crops
        for planted in (user.plantedCrops ?? []) {
            if let crop = planted.crop, let growTime = crop.growTime, planted.plantedAt.addingTimeInterval(growTime) <= now {
                SanctuaryManager.shared.harvest(plantedItem: planted, for: user, context: modelContext)
            }
        }
        // Trees
        for planted in (user.plantedTrees ?? []) {
            if let tree = planted.tree, let growTime = tree.growTime, planted.plantedAt.addingTimeInterval(growTime) <= now {
                SanctuaryManager.shared.harvest(plantedItem: planted, for: user, context: modelContext)
            }
        }
    }

    private func quickstartGathering() {
        // Ensure some gold for hiring
        if user.gold < 600 { user.gold = 600 }
        // Hire a Forager and a Gardener if missing
        if !(user.guildMembers ?? []).contains(where: { $0.role == .forager }) {
            _ = GuildManager.shared.hireGuildMember(role: .forager, for: user, context: modelContext)
        }
        if !(user.guildMembers ?? []).contains(where: { $0.role == .gardener }) {
            _ = GuildManager.shared.hireGuildMember(role: .gardener, for: user, context: modelContext)
        }
        // Seed some inventory
        func addItem(_ id: String, qty: Int) {
            if let existing = user.inventory?.first(where: { $0.itemID == id }) { existing.quantity += qty }
            else { user.inventory?.append(InventoryItem(itemID: id, quantity: qty, owner: user)) }
        }
        addItem("seed_vigor", qty: 3)
        addItem("seed_serenity", qty: 2)
        addItem("crop_sunwheat", qty: 2)
        // Plant up to 3 plots
        let plantIDs = ["seed_vigor", "seed_serenity", "crop_sunwheat"]
        for pid in plantIDs {
            SanctuaryManager.shared.plantItem(itemID: pid, for: user, context: modelContext)
        }
    }
}

// MARK: - Compact Bounty Card for Hall
struct GuildBountySummaryCard: View {
    let bounty: GuildBounty
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "scroll.fill").foregroundColor(.orange)
            VStack(alignment: .leading, spacing: 4) {
                Text(bounty.title).font(.headline)
                Text(bounty.bountyDescription).font(.caption).foregroundColor(.secondary).lineLimit(2)
                ProgressView(value: Double(bounty.currentProgress), total: Double(bounty.requiredProgress))
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Label("\(bounty.guildXpReward) XP", systemImage: "star.fill").font(.caption).foregroundColor(.yellow)
                Label("\(bounty.guildSealReward) Seals", systemImage: "seal.fill").font(.caption).foregroundColor(.orange)
            }
        }
        .padding()
        .background(Material.regular)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Expeditions Grid (reuses GM filtering)
struct AvailableExpeditionsGrid: View {
    let user: User
    let mode: ExpeditionMode
    let onSelect: (Expedition) -> Void
    var body: some View {
        AvailableExpeditionsSection(availableMembers: (user.guildMembers ?? []).filter { member in
            guard !member.isOnExpedition else { return false }
            switch mode {
            case .combat: return member.isCombatant
            case .gathering: return member.role.isGathererRole
            case .all: return true
            }
        }, mode: mode) { expedition in onSelect(expedition) }
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
        let cost = GuildManager.shared.getHireCost(for: role, user: user)
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

struct EnhancedBountyCard: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var bounty: GuildBounty
    @Bindable var user: User

    private var isComplete: Bool { bounty.currentProgress >= bounty.requiredProgress }

    @State private var showStartHuntSheet: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "scroll.fill").foregroundColor(.orange)
                VStack(alignment: .leading) {
                    Text(bounty.title).font(.headline)
                    Text(bounty.bountyDescription).font(.caption).foregroundColor(.secondary).lineLimit(2)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Label("\(bounty.guildXpReward) XP", systemImage: "star.fill").font(.caption).foregroundColor(.yellow)
                    Label("\(bounty.guildSealReward) Seals", systemImage: "seal.fill").font(.caption).foregroundColor(.orange)
                }
            }
            ProgressView(value: Double(bounty.currentProgress), total: Double(bounty.requiredProgress))
                .tint(isComplete ? .green : .blue)

            HStack(spacing: 8) {
                if !isComplete {
                    Button("Work +1") { bounty.currentProgress = min(bounty.currentProgress + 1, bounty.requiredProgress) }
                        .buttonStyle(.bordered)
                    if let target = bounty.targetEnemyID {
                        Button("Hunt Target") { showStartHuntSheet = true }
                            .buttonStyle(.borderedProminent)
                            .tint(.red)
                        roleHintsView(for: target)
                    }
                    Button("Reroll") {
                        GuildManager.shared.rerollBounty(bounty, for: user, context: modelContext)
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button("Turn In") {
                        GuildManager.shared.completeBounty(bounty: bounty, for: user)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding()
        .background(Material.regular)
        .cornerRadius(12)
        .sheet(isPresented: $showStartHuntSheet) {
            if let target = bounty.targetEnemyID {
                StartHuntView(user: user, modelContext: modelContext, prefillEnemyID: target)
            }
        }
    }

    private func roleHintsView(for enemyID: String) -> some View {
        let mults = GuildManager.shared.getEnemyRoleMultipliers(enemyID)
        let topArray = Array(mults.sorted { $0.value > $1.value }.prefix(2))
        return HStack(spacing: 6) {
            ForEach(Array(topArray.enumerated()), id: \.offset) { _, element in
                let role = element.key
                let mult = element.value
                HStack(spacing: 4) {
                    Image(systemName: iconName(for: role))
                    Text("x\(String(format: "%.2f", mult))")
                }
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.blue.opacity(0.12))
                .cornerRadius(4)
            }
        }
    }

    private func iconName(for role: GuildMember.Role) -> String {
        switch role {
        case .knight: return "shield.fill"
        case .archer: return "arrow.up.right"
        case .wizard: return "sparkles"
        case .rogue: return "bolt.fill"
        case .cleric: return "cross.fill"
        default: return "person.fill"
        }
    }
}
