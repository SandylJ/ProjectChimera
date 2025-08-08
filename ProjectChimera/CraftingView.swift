import SwiftUI
import SwiftData

struct CraftingView: View {
    @Bindable var user: User
    
    // Get all available recipes from the database
    private let recipes = ItemDatabase.shared.masterRecipeList
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                
                // Header
                Text("Gold: \(user.gold) 🪙")
                    .font(.title2.bold())
                    .padding([.horizontal, .top])
                
                // Recipe List
                ForEach(recipes) { recipe in
                    RecipeCardView(recipe: recipe, user: user)
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Crafting Station")
    }
}

// MARK: - Recipe Card View
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
        .padding(.horizontal)
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
