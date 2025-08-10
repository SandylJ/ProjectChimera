import SwiftUI
import SwiftData

struct CraftingView: View {
    @Bindable var user: User
    @Environment(\.modelContext) private var modelContext
    @State private var now = Date()
    private let timer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()

    // Get all available recipes from the database
    private let recipes = ItemDatabase.shared.masterRecipeList

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                // Header
                HStack {
                    Text("Crafting Workshop")
                        .font(.title.bold())
                    Spacer()
                    Label("\(user.gold)", systemImage: "dollarsign.circle.fill")
                        .foregroundColor(.yellow)
                        .font(.headline)
                }
                .padding([.horizontal, .top])

                // Unclaimed crafted items
                if !user.unclaimedCraftedItems.isEmpty {
                    CraftedUnclaimedSection(user: user)
                        .padding(.horizontal)
                }

                // Live production dashboard
                CraftingProductionDashboard(user: user)
                    .padding(.horizontal)

                // Recipe List
                if !recipes.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Manual Recipes")
                            .font(.headline)
                        ForEach(recipes) { recipe in
                            RecipeCardView(recipe: recipe, user: user)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Crafting Station")
        .onReceive(timer) { _ in
            GuildManager.shared.processCrafting(for: user, deltaTime: 1.0)
            self.now = Date()
        }
    }
}

// MARK: - Crafted Unclaimed Section
struct CraftedUnclaimedSection: View {
    @Bindable var user: User

    private var totalItems: Int {
        user.unclaimedCraftedItems.reduce(0) { $0 + $1.quantity }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Unclaimed Crafts")
                    .font(.subheadline.bold())
                Spacer()
                Text("\(totalItems) items")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            ForEach(user.unclaimedCraftedItems, id: \.itemID) { entry in
                HStack {
                    Image(systemName: ItemDatabase.shared.getItem(id: entry.itemID)?.icon ?? "bag.fill")
                        .foregroundColor(.blue)
                    Text("\(entry.quantity)x \(ItemDatabase.shared.getItem(id: entry.itemID)?.name ?? entry.itemID)")
                        .font(.subheadline)
                    Spacer()
                }
            }

            Button {
                GuildManager.shared.claimCraftedItems(for: user)
            } label: {
                Label("Claim All", systemImage: "tray.and.arrow.down.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding()
        .background(Color.blue.opacity(0.08))
        .cornerRadius(10)
    }
}

// MARK: - Production Dashboard
struct CraftingProductionDashboard: View {
    @Bindable var user: User

    private var roles: [GuildMember.Role] { [.leatherworker, .spinner, .weaver] }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Crafting Crew")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 12)], spacing: 12) {
                ForEach(roles, id: \.self) { role in
                    CraftingRoleCard(role: role, user: user)
                }
            }
        }
    }
}

struct CraftingRoleCard: View {
    let role: GuildMember.Role
    @Bindable var user: User
    @Environment(\.modelContext) private var modelContext

    private var members: [GuildMember] {
        (user.guildMembers ?? []).filter { $0.role == role }
    }

    private var itemsPerHour: Int {
        let baseSeconds: Double
        switch role {
        case .leatherworker: baseSeconds = 300
        case .spinner: baseSeconds = 180
        case .weaver: baseSeconds = 420
        default:
            baseSeconds = 99999
        }
        guard !members.isEmpty else { return 0 }
        let iph = members.reduce(0.0) { partial, m in
            let mult = 1.0 + 0.1 * Double(max(0, m.level - 1))
            let spi = max(10.0, baseSeconds / mult)
            return partial + (3600.0 / spi)
        }
        return Int(iph)
    }

    private var progress: Double {
        let key = role.rawValue.lowercased()
        return min(user.craftingProgress[key] ?? 0.0, 1.0)
    }

    private var item: Item? {
        switch role {
        case .leatherworker: return ItemDatabase.shared.getItem(id: "material_tanned_leather")
        case .spinner: return ItemDatabase.shared.getItem(id: "material_spun_flax")
        case .weaver: return ItemDatabase.shared.getItem(id: "material_linen")
        default: return nil
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: item?.icon ?? "hammer")
                        .foregroundColor(.primary)
                    Text(role.rawValue)
                        .font(.headline)
                }
                Spacer()
                if !members.isEmpty {
                    Text("Lv avg \(averageLevel, specifier: "%.1f") • \(members.count)x")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if members.isEmpty {
                HStack {
                    Text("No \(role.rawValue)s yet.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("Hire") {
                        _ = GuildManager.shared.hireGuildMember(role: role, for: user, context: modelContext)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            } else {
                HStack(spacing: 8) {
                    ProgressView(value: progress)
                        .progressViewStyle(.linear)
                    Text("\(itemsPerHour) / hr")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 2)

                HStack {
                    Button("Upgrade All") {
                        for m in members { GuildManager.shared.upgradeGuildMember(member: m, user: user, context: modelContext) }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Spacer()

                    if let it = item {
                        Text("Produces: \(it.name)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Material.regular)
        .cornerRadius(12)
    }

    private var averageLevel: Double {
        guard !members.isEmpty else { return 0 }
        let total = members.reduce(0) { $0 + $1.level }
        return Double(total) / Double(members.count)
    }
}

// MARK: - Recipe Card View (unchanged)
struct RecipeCardView: View {
    @Environment(\.modelContext) private var modelContext
    let recipe: Recipe
    @Bindable var user: User
    
    @State private var craftSuccessTrigger = false
    
    private var canCraft: Bool {
        CraftingManager.shared.canCraft(recipe, user: user)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Crafted Item Header
            if let item = recipe.craftedItem {
                HStack {
                    Image(systemName: item.icon)
                        .font(.title)
                        .foregroundColor(rarityColor(for: item.rarity))
                    Text("Craft: \(item.name)")
                        .font(.headline.bold())
                }
            }
            
            Divider()
            
            // Required Materials
            Text("Requires:").font(.caption).bold()
            
            ForEach(Array(recipe.requiredMaterials.keys), id: \.self) { itemID in
                if let material = ItemDatabase.shared.getItem(id: itemID) {
                    let requiredCount = recipe.requiredMaterials[itemID]!
                    let userCount = user.inventory?.first(where: { $0.itemID == itemID })?.quantity ?? 0
                    
                    HStack {
                        Text("- \(material.name):")
                        Spacer()
                        Text("\(userCount) / \(requiredCount)")
                            .foregroundColor(userCount >= requiredCount ? .primary : .red)
                    }
                    .font(.caption)
                }
            }
            
            // Gold Cost
            HStack {
                Text("- Gold:")
                Spacer()
                Text("\(user.gold) / \(recipe.requiredGold)")
                    .foregroundColor(user.gold >= recipe.requiredGold ? .primary : .red)
            }
            .font(.caption)
            
            // Craft Button
            Button("Craft") {
                CraftingManager.shared.craftItem(recipe, user: user, context: modelContext)
                craftSuccessTrigger.toggle()
            }
            .buttonStyle(JuicyButtonStyle())
            .disabled(!canCraft)
            .sensoryFeedback(.success, trigger: craftSuccessTrigger)
            
        }
        .padding()
        .background(Material.regular)
        .cornerRadius(15)
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
