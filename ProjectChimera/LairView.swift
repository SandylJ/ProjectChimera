import SwiftUI
import SwiftData

@available(macOS 14.0, iOS 17.0, *)
struct LairView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var users: [User]
    @State private var user: User?
    
    @State private var upgradeProgress: CGFloat = 0.2
    @State private var isAnimatingReward = false
    @State private var activeTab: LairTab = .wardrobe

    var body: some View {
        ZStack {
            GameTheme.bgGradient.ignoresSafeArea()
            SparkleField()
            
            VStack(spacing: 14) {
                GameHUD(coins: user?.gold ?? 0, gems: user?.runes ?? 0, keys: user?.inventory?.filter { ItemDatabase.shared.getItem(id: $0.itemID)?.itemType == .key }.reduce(0) { $0 + $1.quantity } ?? 0)
                
                if let user = user, let chimera = user.chimera {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 14) {
                            header
                            equippedSection(chimera: chimera)
                            
                            Group {
                                switch activeTab {
                                case .wardrobe:
                                    WardrobePanel(chimera: chimera)
                                case .equipment:
                                    EquipmentPanel(user: user)
                                case .inventory:
                                    InventoryPanel(user: user)
                                case .stats:
                                    statsSection(chimera: chimera)
                                }
                            }
                            .padding(.horizontal, 14)
                            
                            if activeTab == .stats {
                                upgradeButton(user: user, chimera: chimera)
                            }
                        }
                    }
                    .padding(.horizontal)
                } else {
                    GlassCard {
                        VStack(spacing: 12) {
                            Image(systemName: "pawprint.slash").font(.system(size: 46)).foregroundStyle(.white.opacity(0.85))
                            Text("No Chimera Found").font(.title3.weight(.heavy)).foregroundStyle(.white)
                            Text("Complete onboarding or create your companion in the Sanctuary.")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        .padding(18)
                    }
                    .padding(.horizontal)
                }
                
                Spacer(minLength: 0)
                footerBar
            }
        }
        .navigationTitle("Chimera's Lair")
        .onAppear { loadUser() }
    }
    
    private var header: some View {
        HStack {
            Text("Chimera's Lair").font(.system(size: 20, weight: .heavy, design: .rounded)).foregroundStyle(.white)
            Spacer()
            Button { } label: {
                Image(systemName: "xmark").font(.headline)
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(6)
            }
        }
        .padding(.horizontal, 14).padding(.top, 14)
    }
    
    private func equippedSection(chimera: Chimera) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 12)
                .fill(LinearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 72, height: 72)
                .overlay(
                    ChimeraView(chimera: chimera)
                        .font(.system(size: 40))
                        .foregroundStyle(.white)
                )
            
            VStack(alignment: .leading, spacing: 6) {
                Text(chimera.name).font(.headline).foregroundStyle(GameTheme.textPrimary)
                Text("Discipline \(chimera.discipline) • Mindfulness \(chimera.mindfulness)")
                    .font(.footnote).foregroundStyle(GameTheme.textSecondary)
                ProgressBar(progress: upgradeProgress)
                    .frame(height: 10)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            Spacer()
            Chip(text: "Aura: \(chimera.auraEffectID.capitalized.replacingOccurrences(of: "_", with: " "))")
        }
        .padding(14)
        .background(GameTheme.panelFill, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(GameTheme.panelStroke))
        .padding(.horizontal, 14)
    }
    
    private func statsSection(chimera: Chimera) -> some View {
        VStack(spacing: 10) {
            StatRow(label: "Intellect", value: chimera.intellect)
            StatRow(label: "Creativity", value: chimera.creativity)
            StatRow(label: "Resilience", value: chimera.resilience)
        }
    }
    
    private func upgradeButton(user: User, chimera: Chimera) -> some View {
        Button {
            let cost = 25
            if user.gold >= cost {
                user.gold -= cost
                chimera.discipline += 1
                chimera.mindfulness += 1
                upgradeProgress = min(upgradeProgress + 0.2, 1.0)
                if upgradeProgress >= 1.0 { upgradeProgress = 0.05 }
                isAnimatingReward.toggle()
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "arrow.up.circle.fill")
                Text("TRAIN CHIMERA")
                Spacer()
                Image(systemName: "creditcard")
                Text("25")
            }
        }
        .buttonStyle(GlowButtonStyle())
        .padding(.horizontal, 14)
        .padding(.bottom, 16)
    }
    
    private var footerBar: some View {
        HStack {
            TabItem(icon: "wand.and.stars", label: "Wardrobe", active: activeTab == .wardrobe)
                .onTapGesture { activeTab = .wardrobe }
            TabItem(icon: "shield.fill", label: "Equipment", active: activeTab == .equipment)
                .onTapGesture { activeTab = .equipment }
            TabItem(icon: "shippingbox.fill", label: "Inventory", active: activeTab == .inventory)
                .onTapGesture { activeTab = .inventory }
            TabItem(icon: "chart.bar.fill", label: "Stats", active: activeTab == .stats)
                .onTapGesture { activeTab = .stats }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.1)))
        .padding(.bottom, 10)
    }
    
    private func loadUser() {
        if let existing = users.first { user = existing; return }
        do {
            let descriptor = FetchDescriptor<User>()
            let fetched = try modelContext.fetch(descriptor)
            user = fetched.first
        } catch {
            print("Failed to fetch user: \(error)")
        }
    }
}

private enum LairTab: String, CaseIterable { case wardrobe, equipment, inventory, stats }

// MARK: - Wardrobe Panel
@available(macOS 14.0, iOS 17.0, *)
private struct WardrobePanel: View {
    @Bindable var chimera: Chimera
    
    private let auraOptions = ["none", "aura_subtle_t1", "aura_strong_t2"]
    private let headOptions = ["base_head_01", "head_runes_t1", "head_runes_t2", "head_feathers_t2"]
    private let bodyOptions = ["base_body_01", "body_armor_t1", "body_armor_t2", "body_vibrant_t1"]
    private let cosmeticHeadOptions = ["none", "item_hat_wizard", "item_hat_party"]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Wardrobe").font(.title3.bold()).foregroundStyle(.white)
            
            // Chimera preview with optional cosmetic overlay
            ZStack {
                ChimeraView(chimera: chimera)
                    .font(.system(size: 150))
                    .padding(.vertical, 20)
                if chimera.cosmeticHeadItemID != "none" {
                    cosmeticPart(for: chimera.cosmeticHeadItemID)
                        .font(.system(size: 60))
                        .offset(y: -100)
                }
            }
            .frame(maxWidth: .infinity)
            .background(GameTheme.panelFill, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(GameTheme.panelStroke))
            
            // Pickers
            VStack(spacing: 10) {
                labeledPicker(title: "Aura", selection: $chimera.auraEffectID, options: auraOptions)
                labeledPicker(title: "Head", selection: $chimera.headPartID, options: headOptions)
                labeledPicker(title: "Body", selection: $chimera.bodyPartID, options: bodyOptions)
                labeledPicker(title: "Cosmetic Head", selection: $chimera.cosmeticHeadItemID, options: cosmeticHeadOptions, prettifyPrefix: "item_hat_")
            }
        }
        .foregroundStyle(GameTheme.textPrimary)
    }
    
    private func labeledPicker(title: String, selection: Binding<String>, options: [String], prettifyPrefix: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline).foregroundStyle(GameTheme.textSecondary)
            Picker(title, selection: selection) {
                ForEach(options, id: \.self) { option in
                    Text(pretty(option, prettifyPrefix: prettifyPrefix)).tag(option)
                }
            }
            .pickerStyle(.segmented)
        }
    }
    
    private func pretty(_ raw: String, prettifyPrefix: String?) -> String {
        var text = raw
        if let prefix = prettifyPrefix { text = text.replacingOccurrences(of: prefix, with: "") }
        return text.replacingOccurrences(of: "_", with: " ").capitalized
    }
    
    @ViewBuilder
    private func cosmeticPart(for id: String) -> some View {
        switch id {
        case "item_hat_wizard":
            Image(systemName: "graduationcap.fill").foregroundColor(.purple)
        case "item_hat_party":
            Image(systemName: "party.popper.fill").foregroundColor(.yellow)
        default:
            EmptyView()
        }
    }
}

// MARK: - Equipment Panel
@available(macOS 14.0, iOS 17.0, *)
private struct EquipmentPanel: View {
    @Bindable var user: User
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Equipment").font(.title3.bold()).foregroundStyle(.white)
            
            VStack(spacing: 12) {
                ForEach(EquipmentSlot.allCases, id: \.self) { slot in
                    EquipmentSlotRow(slot: slot, itemID: user.equippedItems[slot], onUnequip: {
                        EquipmentManager.shared.unequipItem(slot: slot, for: user)
                    })
                }
            }
            .padding(12)
            .background(GameTheme.panelFill, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(GameTheme.panelStroke))
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Total Bonuses").font(.headline)
                ForEach(EquipmentManager.shared.getBonuses(for: user), id: \.self) { bonus in
                    Text("+\(bonus.value) \(bonus.stat.rawValue.capitalized)")
                        .foregroundStyle(GameTheme.textSecondary)
                }
            }
            .padding(12)
            .background(GameTheme.panelFill, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(GameTheme.panelStroke))
        }
    }
}

// MARK: - Inventory Panel
@available(macOS 14.0, iOS 17.0, *)
private struct InventoryPanel: View {
    @Bindable var user: User
    @State private var filter: InventoryFilter = .all
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Inventory").font(.title3.bold()).foregroundStyle(.white)
                Spacer()
                Picker("Filter", selection: $filter) {
                    ForEach(InventoryFilter.allCases, id: \.self) { f in
                        Text(f.title).tag(f)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 360)
            }
            
            if let items = user.inventory, !items.isEmpty {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 12)], spacing: 12) {
                        ForEach(filtered(items)) { inv in
                            InventoryCell(inventoryItem: inv)
                                .onTapGesture {
                                    if let item = ItemDatabase.shared.getItem(id: inv.itemID), item.itemType == .equippable {
                                        EquipmentManager.shared.equipItem(itemID: inv.itemID, for: user)
                                    }
                                }
                        }
                    }
                    .padding(6)
                }
                .background(GameTheme.panelFill, in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(GameTheme.panelStroke))
            } else {
                Text("No items yet. Complete tasks, craft, or open chests to fill your lair.")
                    .foregroundStyle(GameTheme.textSecondary)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(GameTheme.panelFill, in: RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(GameTheme.panelStroke))
            }
        }
    }
    
    private func filtered(_ list: [InventoryItem]) -> [InventoryItem] {
        list.filter { inv in
            guard let item = ItemDatabase.shared.getItem(id: inv.itemID) else { return false }
            switch filter {
            case .all: return true
            case .equippable: return item.itemType == .equippable
            case .consumable: return item.itemType == .consumable
            case .material: return item.itemType == .material
            case .plantable: return item.itemType == .plantable
            case .keys: return item.itemType == .key
            }
        }
    }
}

private enum InventoryFilter: CaseIterable { case all, equippable, consumable, material, plantable, keys
    var title: String {
        switch self {
        case .all: return "All"
        case .equippable: return "Equippable"
        case .consumable: return "Consumables"
        case .material: return "Materials"
        case .plantable: return "Plantables"
        case .keys: return "Keys"
        }
    }
}

@available(macOS 14.0, iOS 17.0, *)
private struct InventoryCell: View {
    let inventoryItem: InventoryItem
    var body: some View {
        let item = ItemDatabase.shared.getItem(id: inventoryItem.itemID)
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(GameTheme.panelFill)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(GameTheme.panelStroke))
                    .frame(height: 90)
                if let icon = item?.icon {
                    Image(systemName: icon)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.white)
                } else {
                    Image(systemName: "questionmark").foregroundStyle(.white)
                }
                
                VStack {
                    HStack {
                        Spacer()
                        Text("x\(inventoryItem.quantity)")
                            .font(.caption2).bold().padding(6)
                            .background(.white.opacity(0.14), in: Capsule())
                            .overlay(Capsule().stroke(.white.opacity(0.15)))
                            .foregroundStyle(.white)
                    }
                    Spacer()
                }
                .padding(8)
            }
            
            Text(item?.name ?? inventoryItem.itemID)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(GameTheme.textPrimary)
                .lineLimit(1)
        }
        .padding(8)
        .background(rarityBackground(item?.rarity), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.08)))
    }
    
    private func rarityBackground(_ rarity: Rarity?) -> LinearGradient {
        switch rarity {
        case .common: return LinearGradient(colors: [.white.opacity(0.02), .white.opacity(0.02)], startPoint: .top, endPoint: .bottom)
        case .rare: return LinearGradient(colors: [.blue.opacity(0.20), .purple.opacity(0.15)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .epic: return LinearGradient(colors: [.purple.opacity(0.25), .pink.opacity(0.20)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .legendary: return LinearGradient(colors: [.orange.opacity(0.30), .yellow.opacity(0.25)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .none: return LinearGradient(colors: [.clear, .clear], startPoint: .top, endPoint: .bottom)
        }
    }
}

// MARK: - Legacy WardrobeView kept for reference (unused directly)
@available(macOS 14.0, iOS 17.0, *)
struct WardrobeView: View {
    @Bindable var chimera: Chimera
    
    // Simple list of available cosmetic items
    let cosmeticItems = ["item_hat_wizard", "item_hat_party", "none"]

    var body: some View {
        VStack {
            Text("Wardrobe")
                .font(.title2).bold()
                .padding(.top)
            
            Picker("Equip Cosmetic", selection: $chimera.cosmeticHeadItemID) {
                ForEach(cosmeticItems, id: \.self) { item in
                    Text(item.replacingOccurrences(of: "item_hat_", with: "").capitalized).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            
            // The ZStack now correctly layers the Chimera and the selected cosmetic item.
            ZStack {
                // This now works because ChimeraView is accessible.
                ChimeraView(chimera: chimera)
                    .font(.system(size: 150))
                    .padding(.vertical, 40)
                
                if chimera.cosmeticHeadItemID != "none" {
                    cosmeticPart(for: chimera.cosmeticHeadItemID)
                        .font(.system(size: 60))
                        .offset(y: -100) // Adjust position as needed
                }
            }
            
            Spacer()
        }
    }
    
    /// A view builder for rendering cosmetic parts based on their ID.
    @ViewBuilder
    private func cosmeticPart(for id: String) -> some View {
        switch id {
        case "item_hat_wizard":
            Image(systemName: "graduationcap.fill").foregroundColor(.purple)
        case "item_hat_party":
            Image(systemName: "party.popper.fill").foregroundColor(.yellow)
        default:
            EmptyView()
        }
    }
}

#Preview {
    // We must create a dummy User in a temporary in-memory container for the preview to work.
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: User.self, configurations: config)
    
    let user = User(username: "PreviewUser")
    container.mainContext.insert(user)
    
    return NavigationStack {
        LairView()
    }
    .modelContainer(container)
}
