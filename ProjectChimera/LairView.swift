import SwiftUI
import SwiftData

@available(macOS 14.0, iOS 17.0, *)
struct LairView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var users: [User]
    @State private var user: User?
    
    @State private var upgradeProgress: CGFloat = 0.2
    @State private var isAnimatingReward = false

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
                            statsSection(chimera: chimera)
                            upgradeButton(user: user, chimera: chimera)
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
        .padding(.horizontal, 14)
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
            TabItem(icon: "wand.and.stars", label: "Wardrobe", active: false)
            TabItem(icon: "sparkles", label: "Evolve", active: false)
            TabItem(icon: "chart.bar.fill", label: "Stats", active: true)
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

// MARK: - Wardrobe View
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
