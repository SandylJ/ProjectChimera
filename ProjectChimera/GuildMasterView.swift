import SwiftUI
import SwiftData

struct GuildMasterView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var user: User
    @State private var selectedTab: GuildTab = .overview
    @State private var lastAppearance: Date = Date()
    @State private var isLoading = true

    private var guild: Guild? { user.guild }
    private var activeBounties: [GuildBounty] { (user.guildBounties ?? []).filter { $0.isActive } }
    private var guildMembers: [GuildMember] { user.guildMembers ?? [] }

    var body: some View {
        Group {
            if isLoading {
                LoadingView()
            } else {
                VStack(spacing: 0) {
                    // Header with Guild Status
                    GuildHeaderView(guild: guild, user: user)
                    
                    // Tab Navigation
                    GuildTabNavigation(selectedTab: $selectedTab)
                    
                    // Main Content
                    TabView(selection: $selectedTab) {
                        GuildOverviewTab(user: user, guild: guild, modelContext: modelContext)
                            .tag(GuildTab.overview)
                        
                        GuildMembersTab(user: user, guildMembers: guildMembers, modelContext: modelContext)
                            .tag(GuildTab.members)
                        
                        GuildBountiesTab(user: user, activeBounties: activeBounties)
                            .tag(GuildTab.bounties)
                        
                        GuildExpeditionsTab(user: user, modelContext: modelContext)
                            .tag(GuildTab.expeditions)
                        
                        GuildProjectsTab(user: user, guild: guild)
                            .tag(GuildTab.projects)
                    }
                    .tabViewStyle(.automatic)
                }
                .navigationTitle("Guild Master")
                .navigationTitle("Guild Master")
                .background(guildHallBackground)
            }
        }
        .onAppear {
            initializeGuild()
            let timePassed = Date().timeIntervalSince(lastAppearance)
            GuildManager.shared.processHunts(for: user, deltaTime: timePassed, context: modelContext)
            lastAppearance = Date()
        }
    }
    
    private func initializeGuild() {
        // Ensure guild is initialized
        if user.guild == nil {
            GuildManager.shared.initializeGuild(for: user, context: modelContext)
        }
        
        // Generate bounties if none exist
        if user.guildBounties?.isEmpty ?? true {
            GuildManager.shared.generateDailyBounties(for: user, context: modelContext)
        }
        
        // Ensure arrays are initialized
        if user.guildMembers == nil {
            user.guildMembers = []
        }
        if user.guildBounties == nil {
            user.guildBounties = []
        }
        if user.activeHunts == nil {
            user.activeHunts = []
        }
        
        // Small delay to ensure data is loaded
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isLoading = false
        }
    }
    
    private var guildHallBackground: some View {
        ZStack {
            // Base gradient
            LinearGradient(
                colors: guildThemeColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .opacity(0.1)
            
            // Subtle pattern overlay
            GeometryReader { geometry in
                Path { path in
                    let size = geometry.size
                    let spacing: CGFloat = 40
                    
                    for x in stride(from: 0, through: size.width, by: spacing) {
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: size.height))
                    }
                    
                    for y in stride(from: 0, through: size.height, by: spacing) {
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: size.width, y: y))
                    }
                }
                .stroke(Color.primary.opacity(0.05), lineWidth: 0.5)
            }
        }
        .ignoresSafeArea()
    }
    
    private var guildThemeColors: [Color] {
        guard let guild = guild else { return [.blue, .purple] }
        switch guild.level {
        case 1...5: return [.gray, .blue] // Novice
        case 6...10: return [.green, .blue] // Respected
        case 11...15: return [.blue, .purple] // Honored
        case 16...20: return [.purple, .orange] // Revered
        default: return [.orange, .red] // Legendary
        }
    }
}

// MARK: - Loading View
struct LoadingView: View {
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Loading Guild Master...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Material.regular)
    }
}

// MARK: - Guild Tabs
enum GuildTab: String, CaseIterable {
    case overview = "Overview"
    case members = "Members"
    case bounties = "Bounties"
    case expeditions = "Expeditions"
    case projects = "Projects"
    
    var icon: String {
        switch self {
        case .overview: return "house.fill"
        case .members: return "person.3.fill"
        case .bounties: return "scroll.fill"
        case .expeditions: return "map.fill"
        case .projects: return "hammer.fill"
        }
    }
}

// MARK: - Guild Header
struct GuildHeaderView: View {
    let guild: Guild?
    let user: User
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(guild?.name ?? "Your Guild")
                        .font(.title2.bold())
                        .foregroundColor(.primary)
                    
                    Text("Level \(guild?.level ?? 1)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(user.guildSeals)")
                        .font(.title3.bold())
                        .foregroundColor(.orange)
                    
                    Text("Guild Seals")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if let guild = guild {
                GuildProgressBar(guild: guild)
            }
            
            // Guild Reputation Badge
            GuildReputationBadge(guild: guild)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Material.ultraThin)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                )
        )
        .padding(.horizontal)
    }
}

struct GuildReputationBadge: View {
    let guild: Guild?
    
    var reputationLevel: String {
        guard let guild = guild else { return "Novice" }
        switch guild.level {
        case 1...5: return "Novice"
        case 6...10: return "Respected"
        case 11...15: return "Honored"
        case 16...20: return "Revered"
        default: return "Legendary"
        }
    }
    
    var reputationColor: Color {
        switch reputationLevel {
        case "Novice": return .gray
        case "Respected": return .green
        case "Honored": return .blue
        case "Revered": return .purple
        case "Legendary": return .orange
        default: return .gray
        }
    }
    
    var body: some View {
        HStack {
            Image(systemName: "star.fill")
                .foregroundColor(reputationColor)
                .font(.caption)
            
            Text(reputationLevel)
                .font(.caption.bold())
                .foregroundColor(reputationColor)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(reputationColor.opacity(0.1))
        .cornerRadius(8)
    }
}

struct GuildProgressBar: View {
    let guild: Guild
    
    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text("Guild XP")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("\(guild.xp) / \(guild.xpToNextLevel)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            ProgressView(value: Double(guild.xp), total: Double(guild.xpToNextLevel))
                .progressViewStyle(.linear)
                .tint(.blue)
        }
    }
}

// MARK: - Tab Navigation
struct GuildTabNavigation: View {
    @Binding var selectedTab: GuildTab
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(GuildTab.allCases, id: \.self) { tab in
                    GuildTabButton(
                        tab: tab,
                        isSelected: selectedTab == tab,
                        action: { selectedTab = tab }
                    )
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
    }
}

struct GuildTabButton: View {
    let tab: GuildTab
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: tab.icon)
                    .font(.system(size: 20))
                
                Text(tab.rawValue)
                    .font(.caption)
            }
            .foregroundColor(isSelected ? .white : .primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.blue : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Overview Tab
struct GuildOverviewTab: View {
    let user: User
    let guild: Guild?
    let modelContext: ModelContext
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Quick Stats
                GuildStatsGrid(user: user, guild: guild)
                
                // Active Hunts
                ActiveHuntsCard(user: user, modelContext: modelContext)
                
                // Recent Activity
                RecentActivityCard(user: user)
                
                // Guild Perks
                if let guild = guild, !guild.unlockedPerks.isEmpty {
                    GuildPerksCard(guild: guild)
                }
            }
            .padding()
        }
    }
}

struct GuildStatsGrid: View {
    let user: User
    let guild: Guild?
    
    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            StatCard(
                title: "Members",
                value: "\(user.guildMembers?.count ?? 0)",
                icon: "person.3.fill",
                color: .blue
            )
            
            StatCard(
                title: "Active Hunts",
                value: "\(user.activeHunts?.count ?? 0)",
                icon: "crosshairs",
                color: .red
            )
            
            StatCard(
                title: "Guild Level",
                value: "\(guild?.level ?? 1)",
                icon: "star.fill",
                color: .yellow
            )
            
            StatCard(
                title: "Unclaimed Gold",
                value: "\(user.unclaimedHuntGold)",
                icon: "dollarsign.circle.fill",
                color: .green
            )
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title2.bold())
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Material.regular)
        .cornerRadius(12)
    }
}

struct ActiveHuntsCard: View {
    let user: User
    let modelContext: ModelContext
    @State private var showingHuntDetails = false
    @State private var selectedHunt: ActiveHunt?
    @State private var showingUpgradeMenu = false
    @State private var now = Date()
    
    private let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
    
    private var totalDPS: Double {
        let combatants = (user.guildMembers ?? []).filter { $0.isCombatant }
        return combatants.reduce(0.0) { total, member in
            total + member.combatDPS()
        }
    }
    
    private var totalKillsPerHour: Int {
        return Int(totalDPS / 10.0 * 3600) // Convert DPS to kills per hour
    }
    
    private var totalGoldPerHour: Int {
        return totalKillsPerHour * 5 // Base 5 gold per kill
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with stats
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Passive Hunting")
                        .font(.headline)
                    
                    Text("\(user.activeHunts?.count ?? 0) active hunts")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(totalKillsPerHour)/hr")
                        .font(.subheadline.bold())
                        .foregroundColor(.green)
                        .animation(.easeInOut(duration: 0.5), value: totalKillsPerHour)
                    
                    Text("\(totalGoldPerHour) gold/hr")
                        .font(.caption)
                        .foregroundColor(.yellow)
                        .animation(.easeInOut(duration: 0.5), value: totalGoldPerHour)
                }
            }
            
            // Unclaimed rewards section
            if user.unclaimedHuntGold > 0 || !user.unclaimedHuntItems.isEmpty {
                UnclaimedRewardsSection(user: user, modelContext: modelContext)
            }
            
            // Active hunts
            if let activeHunts = user.activeHunts, !activeHunts.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Active Hunts")
                        .font(.subheadline.bold())
                    
                    ForEach(activeHunts) { hunt in
                        EnhancedHuntProgressRow(
                            hunt: hunt,
                            user: user,
                            now: now,
                            onTap: {
                                selectedHunt = hunt
                                showingHuntDetails = true
                            }
                        )
                    }
                }
            }
            
            Divider()
            
            // Hunt management
            HStack {
                Button("Start New Hunt") {
                    showingUpgradeMenu = true
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                
                Spacer()
                
                Button("Upgrade Hunters") {
                    showingUpgradeMenu = true
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding()
        .background(Material.regular)
        .cornerRadius(12)
        .sheet(isPresented: $showingHuntDetails) {
            if let hunt = selectedHunt {
                LiveHuntDetailView(hunt: hunt, user: user, modelContext: modelContext)
            }
        }
        .sheet(isPresented: $showingUpgradeMenu) {
            HuntUpgradeView(user: user, modelContext: modelContext)
        }
        .onReceive(timer) { newDate in
            self.now = newDate
            // Process hunts in real-time
            GuildManager.shared.processHunts(for: user, deltaTime: 0.5, context: modelContext)
        }
    }
}

struct UnclaimedRewardsSection: View {
    let user: User
    let modelContext: ModelContext
    @State private var isClaiming = false
    
    private var totalRewardValue: Int {
        var total = user.unclaimedHuntGold
        for item in user.unclaimedHuntItems {
            total += item.quantity * 10 // Approximate item value
        }
        return total
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Unclaimed Rewards")
                    .font(.subheadline.bold())
                
                Spacer()
                
                Text("\(totalRewardValue) total value")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Gold rewards
            if user.unclaimedHuntGold > 0 {
                HStack {
                    Image(systemName: "dollarsign.circle.fill")
                        .foregroundColor(.yellow)
                    Text("\(user.unclaimedHuntGold) Gold")
                        .font(.subheadline)
                    Spacer()
                }
            }
            
            // Item rewards
            ForEach(user.unclaimedHuntItems, id: \.itemID) { item in
                HStack {
                    Image(systemName: "bag.fill")
                        .foregroundColor(.green)
                    Text("\(item.quantity)x \(item.itemID.replacingOccurrences(of: "item_", with: "").capitalized)")
                        .font(.subheadline)
                    Spacer()
                }
            }
            
            Button(action: claimAllRewards) {
                HStack {
                    if isClaiming {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "gift.fill")
                    }
                    Text(isClaiming ? "Claiming..." : "Claim All Rewards")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(isClaiming)
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .cornerRadius(8)
    }
    
    private func claimAllRewards() {
        isClaiming = true
        
        // Add haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        // Animate the claiming process
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Add gold
            user.gold += user.unclaimedHuntGold
            user.unclaimedHuntGold = 0
            
            // Add items to inventory
            for item in user.unclaimedHuntItems {
                if let existingItem = user.inventory?.first(where: { $0.itemID == item.itemID }) {
                    existingItem.quantity += item.quantity
                } else {
                    let newItem = InventoryItem(itemID: item.itemID, quantity: item.quantity, owner: user)
                    user.inventory?.append(newItem)
                }
            }
            user.unclaimedHuntItems.removeAll()
            
            // Success feedback
            let successFeedback = UINotificationFeedbackGenerator()
            successFeedback.notificationOccurred(.success)
            
            isClaiming = false
        }
    }
}

struct EnhancedHuntProgressRow: View {
    let hunt: ActiveHunt
    let user: User
    let now: Date
    let onTap: () -> Void
    
    private var enemyName: String {
        hunt.enemyID.replacingOccurrences(of: "enemy_", with: "").capitalized
    }
    
    private var enemyIcon: String {
        switch hunt.enemyID {
        case "enemy_goblin": return "tortoise.fill"
        case "enemy_zombie": return "bandage.fill"
        case "enemy_spider": return "ant.fill"
        case "enemy_dragon": return "flame.fill"
        case "enemy_skeleton": return "skull.fill"
        case "enemy_ghost": return "sparkles"
        default: return "sword.fill"
        }
    }
    
    private var enemyColor: Color {
        switch hunt.enemyID {
        case "enemy_goblin": return .green
        case "enemy_zombie": return .purple
        case "enemy_spider": return .brown
        case "enemy_dragon": return .red
        case "enemy_skeleton": return .gray
        case "enemy_ghost": return .blue
        default: return .orange
        }
    }
    
    private var killsPerSecond: Double {
        let members = hunt.memberIDs.compactMap { id in
            user.guildMembers?.first { $0.id == id }
        }
        let totalDPS = members.reduce(0.0) { total, member in
            total + member.combatDPS()
        }
        return totalDPS / 10.0 // Convert DPS to kills per second
    }
    
    private var goldPerSecond: Double {
        return killsPerSecond * 5 // Base 5 gold per kill
    }
    
    private var timeSinceLastUpdate: TimeInterval {
        return now.timeIntervalSince(hunt.lastUpdated)
    }
    
    private var estimatedKillsSinceLastUpdate: Int {
        return Int(killsPerSecond * timeSinceLastUpdate)
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Enemy icon with pulsing animation
                ZStack {
                    Circle()
                        .fill(enemyColor.opacity(0.3))
                        .frame(width: 40, height: 40)
                        .scaleEffect(1.0 + 0.1 * sin(now.timeIntervalSince1970 * 2))
                        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: now)
                    
                    Image(systemName: enemyIcon)
                        .font(.title2)
                        .foregroundColor(enemyColor)
                }
                .frame(width: 40, height: 40)
                .background(enemyColor.opacity(0.2))
                .cornerRadius(8)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(enemyName)
                        .font(.subheadline.bold())
                        .foregroundColor(.primary)
                    
                    HStack {
                        Text("\(hunt.killsAccumulated + estimatedKillsSinceLastUpdate) kills")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .animation(.easeInOut(duration: 0.5), value: hunt.killsAccumulated + estimatedKillsSinceLastUpdate)
                        
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("\(Int(killsPerSecond * 3600))/hr")
                            .font(.caption)
                            .foregroundColor(.green)
                            .animation(.easeInOut(duration: 0.5), value: killsPerSecond)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(hunt.memberIDs.count) hunters")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(Int(goldPerSecond * 3600)) gold/hr")
                        .font(.caption)
                        .foregroundColor(.yellow)
                        .animation(.easeInOut(duration: 0.5), value: goldPerSecond)
                }
            }
            .padding()
            .background(Material.thin)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(enemyColor.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct LiveHuntDetailView: View {
    let hunt: ActiveHunt
    let user: User
    let modelContext: ModelContext
    @Environment(\.dismiss) private var dismiss
    @State private var now = Date()
    @State private var particles: [HuntParticle] = []
    
    private let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
    
    private var enemyName: String {
        hunt.enemyID.replacingOccurrences(of: "enemy_", with: "").capitalized
    }
    
    private var enemyIcon: String {
        switch hunt.enemyID {
        case "enemy_goblin": return "tortoise.fill"
        case "enemy_zombie": return "bandage.fill"
        case "enemy_spider": return "ant.fill"
        case "enemy_dragon": return "flame.fill"
        case "enemy_skeleton": return "skull.fill"
        case "enemy_ghost": return "sparkles"
        default: return "sword.fill"
        }
    }
    
    private var enemyColor: Color {
        switch hunt.enemyID {
        case "enemy_goblin": return .green
        case "enemy_zombie": return .purple
        case "enemy_spider": return .brown
        case "enemy_dragon": return .red
        case "enemy_skeleton": return .gray
        case "enemy_ghost": return .blue
        default: return .orange
        }
    }
    
    private var huntMembers: [GuildMember] {
        hunt.memberIDs.compactMap { id in
            user.guildMembers?.first { $0.id == id }
        }
    }
    
    private var totalDPS: Double {
        huntMembers.reduce(0.0) { total, member in
            total + member.combatDPS()
        }
    }
    
    private var killsPerSecond: Double {
        return totalDPS / 10.0
    }
    
    private var goldPerSecond: Double {
        return killsPerSecond * 5
    }
    
    private var timeSinceLastUpdate: TimeInterval {
        return now.timeIntervalSince(hunt.lastUpdated)
    }
    
    private var estimatedKillsSinceLastUpdate: Int {
        return Int(killsPerSecond * timeSinceLastUpdate)
    }
    
    private var totalKills: Int {
        return hunt.killsAccumulated + estimatedKillsSinceLastUpdate
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(colors: [enemyColor.opacity(0.1), enemyColor.opacity(0.05)], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
                
                // Particle effects
                ForEach(particles) { particle in
                    Circle()
                        .fill(particle.color)
                        .frame(width: particle.size, height: particle.size)
                        .position(particle.position)
                        .opacity(particle.opacity)
                        .animation(.easeInOut(duration: 1.0), value: particle.opacity)
                }
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Enemy info with live animation
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(enemyColor.opacity(0.3))
                                    .frame(width: 80, height: 80)
                                    .scaleEffect(1.0 + 0.15 * sin(now.timeIntervalSince1970 * 1.5))
                                    .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: now)
                                
                                Image(systemName: enemyIcon)
                                    .font(.system(size: 40))
                                    .foregroundColor(enemyColor)
                            }
                            
                            Text(enemyName)
                                .font(.title)
                                .bold()
                            
                            Text("Live hunting in progress")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Material.regular)
                        .cornerRadius(12)
                        
                        // Live stats with animations
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                            LiveStatCard(
                                title: "Total Kills",
                                value: "\(totalKills)",
                                icon: "target",
                                color: .red,
                                now: now
                            )
                            LiveStatCard(
                                title: "Kills/Hour",
                                value: "\(Int(killsPerSecond * 3600))",
                                icon: "speedometer",
                                color: .green,
                                now: now
                            )
                            LiveStatCard(
                                title: "Gold/Hour",
                                value: "\(Int(goldPerSecond * 3600))",
                                icon: "dollarsign.circle",
                                color: .yellow,
                                now: now
                            )
                            LiveStatCard(
                                title: "Total DPS",
                                value: "\(Int(totalDPS))",
                                icon: "bolt",
                                color: .blue,
                                now: now
                            )
                        }
                        
                        // Active hunters with live updates
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Active Hunters")
                                .font(.headline)
                            
                            ForEach(huntMembers, id: \.id) { member in
                                LiveHunterRow(member: member, now: now)
                            }
                        }
                        .padding()
                        .background(Material.regular)
                        .cornerRadius(12)
                        
                        // Hunt progress visualization
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Hunt Progress")
                                .font(.headline)
                            
                            ProgressView(value: Double(totalKills % 100) / 100.0)
                                .progressViewStyle(LinearProgressViewStyle(tint: enemyColor))
                                .scaleEffect(x: 1, y: 2, anchor: .center)
                            
                            Text("\(totalKills % 100)/100 kills in current wave")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Material.regular)
                        .cornerRadius(12)
                        
                        // Stop hunt button
                        Button("Stop Hunt") {
                            stopHunt()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                        .frame(maxWidth: .infinity)
                    }
                    .padding()
                }
            }
            .navigationTitle("Live Hunt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onReceive(timer) { newDate in
            self.now = newDate
            updateParticles()
            // Process hunts in real-time
            GuildManager.shared.processHunts(for: user, deltaTime: 0.5, context: modelContext)
        }
    }
    
    private func updateParticles() {
        // Remove old particles
        particles = particles.filter { $0.opacity > 0 }
        
        // Limit the number of particles to prevent performance issues
        if particles.count < 20 {
            // Add new particles based on kills (less frequently)
            if Int(now.timeIntervalSince1970 * 10) % 5 == 0 { // Every 0.5 seconds
                let newParticle = HuntParticle(
                    position: CGPoint(x: CGFloat.random(in: 50...350), y: CGFloat.random(in: 100...600)),
                    color: [enemyColor, .yellow, .green].randomElement()!,
                    size: CGFloat.random(in: 3...8)
                )
                particles.append(newParticle)
            }
        }
        
        // Update existing particles more efficiently
        for i in 0..<particles.count {
            particles[i].opacity -= 0.015 // Slower fade
            particles[i].position.y -= 0.5 // Slower movement
        }
    }
    
    private func stopHunt() {
        // Remove hunt from user's active hunts
        user.activeHunts?.removeAll { $0.id == hunt.id }
        
        // Delete from context
        modelContext.delete(hunt)
        
        dismiss()
    }
}

struct HuntParticle: Identifiable {
    let id = UUID()
    var position: CGPoint
    let color: Color
    let size: CGFloat
    var opacity: Double = 1.0
}

struct LiveStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let now: Date
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 50, height: 50)
                    .scaleEffect(1.0 + 0.1 * sin(now.timeIntervalSince1970 * 3))
                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: now)
                
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
            }
            
            Text(value)
                .font(.title2.bold())
                .foregroundColor(.primary)
                .animation(.easeInOut(duration: 0.5), value: value)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Material.regular)
        .cornerRadius(12)
    }
}

struct LiveHunterRow: View {
    let member: GuildMember
    let now: Date
    
    private var roleIcon: String {
        switch member.role {
        case .knight: return "shield.fill"
        case .archer: return "arrow.up.right"
        case .wizard: return "sparkles"
        case .rogue: return "bolt.fill"
        case .cleric: return "cross.fill"
        default: return "person.fill"
        }
    }
    
    private var roleColor: Color {
        switch member.role {
        case .knight: return .blue
        case .archer: return .gray
        case .wizard: return .purple
        case .rogue: return .orange
        case .cleric: return .green
        default: return .secondary
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(roleColor.opacity(0.2))
                    .frame(width: 40, height: 40)
                    .scaleEffect(1.0 + 0.05 * sin(now.timeIntervalSince1970 * 2 + Double(member.id.hashValue)))
                    .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: now)
                
                Image(systemName: roleIcon)
                    .font(.title3)
                    .foregroundColor(roleColor)
            }
            .frame(width: 40, height: 40)
            .background(roleColor.opacity(0.2))
            .cornerRadius(6)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(member.name)
                    .font(.subheadline.bold())
                
                Text("\(member.role.rawValue) Lv.\(member.level)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(member.combatDPS())) DPS")
                    .font(.subheadline)
                    .foregroundColor(.blue)
                    .animation(.easeInOut(duration: 0.5), value: member.combatDPS())
                
                Text("\(Int(member.combatDPS() / 10.0 * 3600)) kills/hr")
                    .font(.caption)
                    .foregroundColor(.green)
                    .animation(.easeInOut(duration: 0.5), value: member.combatDPS())
            }
        }
        .padding(.vertical, 4)
    }
}

struct HunterRow: View {
    let member: GuildMember
    
    private var roleIcon: String {
        switch member.role {
        case .knight: return "shield.fill"
        case .archer: return "arrow.up.right"
        case .wizard: return "sparkles"
        case .rogue: return "bolt.fill"
        case .cleric: return "cross.fill"
        default: return "person.fill"
        }
    }
    
    private var roleColor: Color {
        switch member.role {
        case .knight: return .blue
        case .archer: return .gray
        case .wizard: return .purple
        case .rogue: return .orange
        case .cleric: return .green
        default: return .secondary
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: roleIcon)
                .font(.title3)
                .foregroundColor(roleColor)
                .frame(width: 32, height: 32)
                .background(roleColor.opacity(0.2))
                .cornerRadius(6)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(member.name)
                    .font(.subheadline.bold())
                
                Text("\(member.role.rawValue) Lv.\(member.level)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(member.combatDPS())) DPS")
                    .font(.subheadline)
                    .foregroundColor(.blue)
                
                Text("\(Int(member.combatDPS() / 10.0 * 3600)) kills/hr")
                    .font(.caption)
                    .foregroundColor(.green)
            }
        }
        .padding(.vertical, 4)
    }
}

struct HuntUpgradeView: View {
    let user: User
    let modelContext: ModelContext
    
    private var combatants: [GuildMember] {
        (user.guildMembers ?? []).filter { $0.isCombatant }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if combatants.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "person.3.fill")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        
                        Text("No Hunters Available")
                            .font(.headline)
                        
                        Text("Hire combat-ready guild members to start hunting")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    ForEach(combatants, id: \.id) { member in
                        HunterUpgradeCard(member: member, user: user, modelContext: modelContext)
                    }
                }
            }
            .padding()
        }
    }
}

struct HunterUpgradeCard: View {
    let member: GuildMember
    let user: User
    let modelContext: ModelContext
    @State private var isUpgrading = false
    
    private var upgradeCost: Int {
        return member.upgradeCost()
    }
    
    private var canAfford: Bool {
        return user.gold >= upgradeCost
    }
    
    private var roleIcon: String {
        switch member.role {
        case .knight: return "shield.fill"
        case .archer: return "arrow.up.right"
        case .wizard: return "sparkles"
        case .rogue: return "bolt.fill"
        case .cleric: return "cross.fill"
        default: return "person.fill"
        }
    }
    
    private var roleColor: Color {
        switch member.role {
        case .knight: return .blue
        case .archer: return .gray
        case .wizard: return .purple
        case .rogue: return .orange
        case .cleric: return .green
        default: return .secondary
        }
    }
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: roleIcon)
                    .font(.title2)
                    .foregroundColor(roleColor)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(member.name)
                        .font(.headline)
                    
                    Text("\(member.role.rawValue) Lv.\(member.level)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Int(member.combatDPS())) DPS")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                    
                    Text("→ \(Int(member.combatDPS() * 1.2)) DPS")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Upgrade Cost")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(upgradeCost) Gold")
                        .font(.subheadline.bold())
                        .foregroundColor(canAfford ? .primary : .red)
                }
                
                Spacer()
                
                Button(action: upgradeHunter) {
                    HStack {
                        if isUpgrading {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "arrow.up.circle.fill")
                        }
                        Text(isUpgrading ? "Upgrading..." : "Upgrade")
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(!canAfford || isUpgrading)
            }
        }
        .padding()
        .background(Material.regular)
        .cornerRadius(12)
    }
    
    private func upgradeHunter() {
        isUpgrading = true
        
        // Add haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        // Animate the upgrade process
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Deduct gold
            user.gold -= upgradeCost
            
            // Upgrade the member
            member.level += 1
            
            // Success feedback
            let successFeedback = UINotificationFeedbackGenerator()
            successFeedback.notificationOccurred(.success)
            
            isUpgrading = false
        }
    }
}

// MARK: - Members Tab
struct GuildMembersTab: View {
    let user: User
    let guildMembers: [GuildMember]
    let modelContext: ModelContext
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Hire New Members
                HireMembersSection(user: user, modelContext: modelContext)
                
                // Current Members (Grouped by Role)
                GroupedMembersSection(guildMembers: guildMembers.filter { $0.isCombatant }, user: user, modelContext: modelContext)
            }
            .padding()
        }
    }
}

struct GroupedMembersSection: View {
    let guildMembers: [GuildMember]
    let user: User
    let modelContext: ModelContext
    
    private var groupedMembers: [GuildMember.Role: [GuildMember]] {
        Dictionary(grouping: guildMembers.filter { $0.isCombatant }) { $0.role }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Guild Members (\(guildMembers.filter { $0.isCombatant }.count))")
                .font(.headline)
            
            if guildMembers.filter({ $0.isCombatant }).isEmpty {
                Text("No members yet. Hire some to get started!")
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                LazyVGrid(columns: [GridItem(.flexible())], spacing: 12) {
                    ForEach(GuildMember.Role.allCases.filter { $0.isCombatantRole }, id: \.self) { role in
                        if let members = groupedMembers[role], !members.isEmpty {
                            RoleGroupCard(
                                role: role,
                                members: members,
                                user: user,
                                modelContext: modelContext
                            )
                        }
                    }
                }
            }
        }
        .padding()
        .background(Material.regular)
        .cornerRadius(12)
    }
}

struct RoleGroupCard: View {
    let role: GuildMember.Role
    let members: [GuildMember]
    let user: User
    let modelContext: ModelContext
    
    @State private var showingBulkUpgradeAlert = false
    @State private var upgradeMessage = ""
    
    private var totalLevel: Int {
        members.reduce(0) { $0 + $1.level }
    }
    
    private var averageLevel: Double {
        members.isEmpty ? 0 : Double(totalLevel) / Double(members.count)
    }
    
    private var totalUpgradeCost: Int {
        members.reduce(0) { $0 + $1.upgradeCost() }
    }
    
    private var canAffordBulkUpgrade: Bool {
        user.gold >= totalUpgradeCost
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with role info
            HStack {
                ZStack {
                    Circle()
                        .fill(roleColor)
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: roleIcon)
                        .foregroundColor(.white)
                        .font(.system(size: 16, weight: .bold))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(role.rawValue)
                        .font(.headline)
                        .bold()
                    
                    Text("\(members.count) member\(members.count == 1 ? "" : "s") • Avg Lv.\(String(format: "%.1f", averageLevel))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Total Level: \(totalLevel)")
                        .font(.subheadline)
                        .bold()
                        .foregroundColor(.blue)
                    
                    Text("\(totalUpgradeCost) Gold")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Member stats summary
            HStack(spacing: 16) {
                if members.contains(where: { $0.isCombatant }) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Total DPS")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(Int(totalDPS))")
                            .font(.subheadline)
                            .bold()
                            .foregroundColor(.red)
                    }
                }
                
                if role.hasSpecialAbility {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Special Ability")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(role.specialAbilityDescription)
                            .font(.caption)
                            .foregroundColor(.purple)
                    }
                }
                
                Spacer()
            }
            
            // Bulk upgrade button
            Button(action: performBulkUpgrade) {
                HStack {
                    Image(systemName: "arrow.up.circle.fill")
                    Text("Upgrade All \(role.rawValue)s")
                    Spacer()
                    Text("\(totalUpgradeCost) Gold")
                        .font(.caption)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(canAffordBulkUpgrade ? Color.blue.opacity(0.2) : Color.gray.opacity(0.2))
                .foregroundColor(canAffordBulkUpgrade ? .blue : .gray)
                .cornerRadius(8)
            }
            .disabled(!canAffordBulkUpgrade)
            .buttonStyle(.plain)
        }
        .padding()
        .background(Material.thin)
        .cornerRadius(12)
        .alert("Bulk Upgrade Result", isPresented: $showingBulkUpgradeAlert) {
            Button("OK") { }
        } message: {
            Text(upgradeMessage)
        }
    }
    
    private var totalDPS: Double {
        members.reduce(0.0) { $0 + $1.combatDPS() }
    }
    
    private var roleColor: Color {
        switch role {
        case .knight: return .blue
        case .archer: return .green
        case .wizard: return .purple
        case .rogue: return .gray
        case .cleric: return .yellow
        case .forager: return .brown
        case .gardener: return .green
        case .alchemist: return .orange
        case .seer: return .indigo
        case .blacksmith: return .red
        }
    }
    
    private var roleIcon: String {
        switch role {
        case .knight: return "shield.fill"
        case .archer: return "arrowshape.turn.up.right.circle.fill"
        case .wizard: return "wand.and.stars"
        case .rogue: return "figure.run.circle.fill"
        case .cleric: return "cross.case.fill"
        case .forager: return "leaf.fill"
        case .gardener: return "tree.fill"
        case .alchemist: return "flask.fill"
        case .seer: return "eye.fill"
        case .blacksmith: return "hammer.fill"
        }
    }
    
    private func performBulkUpgrade() {
        guard canAffordBulkUpgrade else {
            upgradeMessage = "Not enough gold for bulk upgrade"
            showingBulkUpgradeAlert = true
            return
        }
        
        // Perform bulk upgrade
        for member in members {
            GuildManager.shared.upgradeGuildMember(member: member, user: user, context: modelContext)
        }
        
        upgradeMessage = "Upgraded all \(members.count) \(role.rawValue)\(members.count == 1 ? "" : "s")!"
        showingBulkUpgradeAlert = true
    }
}

struct HireMembersSection: View {
    let user: User
    let modelContext: ModelContext
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Hire New Members")
                .font(.headline)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(GuildMember.Role.allCases.filter { $0.isCombatantRole }, id: \.self) { role in
                    HireMemberCard(role: role, user: user, modelContext: modelContext)
                }
            }
        }
        .padding()
        .background(Material.regular)
        .cornerRadius(12)
    }
}

struct HireMemberCard: View {
    let role: GuildMember.Role
    let user: User
    let modelContext: ModelContext
    
    @State private var showingHireAlert = false
    @State private var hireMessage = ""
    
    var body: some View {
        Button {
            let success = GuildManager.shared.hireGuildMember(role: role, for: user, context: modelContext)
            hireMessage = success ? "Hired a \(role.rawValue)!" : "Not enough gold (250 required)"
            showingHireAlert = true
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                showingHireAlert = false
            }
        } label: {
            VStack(spacing: 8) {
                Image(systemName: iconName(for: role))
                    .font(.title2)
                    .foregroundColor(.blue)
                
                Text(role.rawValue)
                    .font(.subheadline.bold())
                
                Text("250 Gold")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Material.thin)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
        .alert("Hire Result", isPresented: $showingHireAlert) {
            Button("OK") { }
        } message: {
            Text(hireMessage)
        }
    }
    
    private func iconName(for role: GuildMember.Role) -> String {
        switch role {
        case .knight: return "shield.fill"
        case .archer: return "arrowshape.turn.up.right.circle.fill"
        case .wizard: return "wand.and.stars"
        case .rogue: return "figure.run.circle.fill"
        case .cleric: return "cross.case.fill"
        case .forager: return "leaf.fill"
        case .gardener: return "tree.fill"
        case .alchemist: return "flask.fill"
        case .seer: return "eye.fill"
        case .blacksmith: return "hammer.fill"
        }
    }
}

struct CurrentMembersSection: View {
    let guildMembers: [GuildMember]
    let user: User
    let modelContext: ModelContext
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Guild Members (\(guildMembers.count))")
                .font(.headline)
            
            if guildMembers.isEmpty {
                Text("No members yet. Hire some to get started!")
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                ForEach(guildMembers) { member in
                    GuildMemberRow(member: member, user: user, modelContext: modelContext)
                }
            }
        }
        .padding()
        .background(Material.regular)
        .cornerRadius(12)
    }
}

struct GuildMemberRow: View {
    let member: GuildMember
    let user: User
    let modelContext: ModelContext
    
    @State private var showingUpgradeAlert = false
    @State private var showingDetails = false
    
    var body: some View {
        Button {
            showingDetails = true
        } label: {
            HStack {
                // Member Avatar
                ZStack {
                    Circle()
                        .fill(memberRoleColor(member.role))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: memberRoleIcon(member.role))
                        .foregroundColor(.white)
                        .font(.system(size: 16, weight: .bold))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(member.name)
                            .font(.subheadline.bold())
                        
                        Text("Lv.\(member.level)")
                            .font(.caption)
                            .foregroundColor(.blue)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .cornerRadius(4)
                    }
                    
                    Text(member.roleDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                    
                    // Member Stats
                    HStack(spacing: 8) {
                        if member.isCombatant {
                            Label("\(Int(member.combatDPS())) DPS", systemImage: "sword")
                                .font(.caption2)
                                .foregroundColor(.red)
                        }
                        
                        if member.isOnExpedition {
                            Label("On Expedition", systemImage: "map")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        }
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Button("Upgrade") {
                        let cost = member.upgradeCost()
                        if user.gold >= cost {
                            GuildManager.shared.upgradeGuildMember(member: member, user: user, context: modelContext)
                            showingUpgradeAlert = true
                        } else {
                            showingUpgradeAlert = true
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    
                    Text("\(member.upgradeCost()) Gold")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Material.thin)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .alert("Upgrade Result", isPresented: $showingUpgradeAlert) {
            Button("OK") { }
        } message: {
            Text(user.gold >= member.upgradeCost() ? "Member upgraded!" : "Not enough gold")
        }
        .sheet(isPresented: $showingDetails) {
            GuildMemberDetailView(member: member, user: user, modelContext: modelContext)
        }
    }
    
    private func memberRoleColor(_ role: GuildMember.Role) -> Color {
        switch role {
        case .knight: return .blue
        case .archer: return .green
        case .wizard: return .purple
        case .rogue: return .gray
        case .cleric: return .yellow
        case .forager: return .brown
        case .gardener: return .green
        case .alchemist: return .orange
        case .seer: return .indigo
        case .blacksmith: return .red
        }
    }
    
    private func memberRoleIcon(_ role: GuildMember.Role) -> String {
        switch role {
        case .knight: return "shield.fill"
        case .archer: return "arrowshape.turn.up.right.circle.fill"
        case .wizard: return "wand.and.stars"
        case .rogue: return "figure.run.circle.fill"
        case .cleric: return "cross.case.fill"
        case .forager: return "leaf.fill"
        case .gardener: return "tree.fill"
        case .alchemist: return "flask.fill"
        case .seer: return "eye.fill"
        case .blacksmith: return "hammer.fill"
        }
    }
}

struct GuildMemberDetailView: View {
    let member: GuildMember
    let user: User
    let modelContext: ModelContext
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Member Header
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(memberRoleColor(member.role))
                                .frame(width: 80, height: 80)
                            
                            Image(systemName: memberRoleIcon(member.role))
                                .foregroundColor(.white)
                                .font(.system(size: 32, weight: .bold))
                        }
                        
                        VStack(spacing: 4) {
                            Text(member.name)
                                .font(.title2.bold())
                            
                            Text(member.role.rawValue)
                                .font(.headline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Member Stats
                    VStack(spacing: 16) {
                        StatRow(title: "Level", value: "\(member.level)", icon: "star.fill", color: .yellow)
                        StatRow(title: "Experience", value: "\(member.xp)", icon: "chart.line.uptrend.xyaxis", color: .blue)
                        
                        if member.isCombatant {
                            StatRow(title: "Combat DPS", value: "\(Int(member.combatDPS()))", icon: "sword", color: .red)
                        }
                        
                        StatRow(title: "Upgrade Cost", value: "\(member.upgradeCost()) Gold", icon: "dollarsign.circle", color: .green)
                    }
                    .padding()
                    .background(Material.regular)
                    .cornerRadius(12)
                    
                    // Member Description
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Role Description")
                            .font(.headline)
                        
                        Text(member.roleDescription)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Material.regular)
                    .cornerRadius(12)
                    
                    // Member Effect
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Current Effect")
                            .font(.headline)
                        
                        Text(member.effectDescription())
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Material.regular)
                    .cornerRadius(12)
                    
                    // Upgrade Button
                    Button("Upgrade Member") {
                        let cost = member.upgradeCost()
                        if user.gold >= cost {
                            GuildManager.shared.upgradeGuildMember(member: member, user: user, context: modelContext)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(user.gold < member.upgradeCost())
                }
                .padding()
            }
            .navigationTitle("Member Details")
            .navigationTitle("Member Details")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func memberRoleColor(_ role: GuildMember.Role) -> Color {
        switch role {
        case .knight: return .blue
        case .archer: return .green
        case .wizard: return .purple
        case .rogue: return .gray
        case .cleric: return .yellow
        case .forager: return .brown
        case .gardener: return .green
        case .alchemist: return .orange
        case .seer: return .indigo
        case .blacksmith: return .red
        }
    }
    
    private func memberRoleIcon(_ role: GuildMember.Role) -> String {
        switch role {
        case .knight: return "shield.fill"
        case .archer: return "arrowshape.turn.up.right.circle.fill"
        case .wizard: return "wand.and.stars"
        case .rogue: return "figure.run.circle.fill"
        case .cleric: return "cross.case.fill"
        case .forager: return "leaf.fill"
        case .gardener: return "tree.fill"
        case .alchemist: return "flask.fill"
        case .seer: return "eye.fill"
        case .blacksmith: return "hammer.fill"
        }
    }
}

struct StatRow: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 20)
            
            Text(title)
                .font(.subheadline)
            
            Spacer()
            
            Text(value)
                .font(.subheadline.bold())
                .foregroundColor(.primary)
        }
    }
}

// MARK: - Bounties Tab
struct GuildBountiesTab: View {
    let user: User
    let activeBounties: [GuildBounty]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if activeBounties.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "scroll")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        
                        Text("No Active Bounties")
                            .font(.headline)
                        
                        Text("Check back tomorrow for new bounties!")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Material.regular)
                    .cornerRadius(12)
                } else {
                    ForEach(activeBounties) { bounty in
                        GuildBountyCard(bounty: bounty, user: user)
                    }
                }
            }
            .padding()
        }
    }
}

struct GuildBountyCard: View {
    let bounty: GuildBounty
    let user: User
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: bountyIcon(for: bounty))
                            .foregroundColor(bountyColor(for: bounty))
                            .font(.title3)
                        
                        Text(bounty.title)
                            .font(.headline)
                    }
                    
                    Text(bounty.bountyDescription)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .foregroundColor(.blue)
                            .font(.caption)
                        Text("\(bounty.guildXpReward) XP")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: "seal.fill")
                            .foregroundColor(.orange)
                            .font(.caption)
                        Text("\(bounty.guildSealReward) Seals")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }
            
            ProgressView(value: Double(bounty.currentProgress), total: Double(bounty.requiredProgress))
                .progressViewStyle(.linear)
                .tint(bountyColor(for: bounty))
            
            HStack {
                Text("\(bounty.currentProgress) / \(bounty.requiredProgress)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if bounty.currentProgress >= bounty.requiredProgress && bounty.isActive {
                    Button("Claim Reward") {
                        GuildManager.shared.completeBounty(bounty: bounty, for: user)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .tint(bountyColor(for: bounty))
                } else if bounty.currentProgress > 0 {
                    Text("In Progress")
                        .font(.caption)
                        .foregroundColor(bountyColor(for: bounty))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(bountyColor(for: bounty).opacity(0.2))
                        .cornerRadius(4)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Material.regular)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(bountyColor(for: bounty).opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private func bountyIcon(for bounty: GuildBounty) -> String {
        if bounty.title.contains("Goblin") || bounty.title.contains("Defeat") {
            return "sword.fill"
        } else if bounty.title.contains("Craft") {
            return "hammer.fill"
        } else if bounty.title.contains("Walk") || bounty.title.contains("Steps") {
            return "figure.walk"
        } else {
            return "scroll.fill"
        }
    }
    
    private func bountyColor(for bounty: GuildBounty) -> Color {
        if bounty.title.contains("Goblin") || bounty.title.contains("Defeat") {
            return .red
        } else if bounty.title.contains("Craft") {
            return .orange
        } else if bounty.title.contains("Walk") || bounty.title.contains("Steps") {
            return .green
        } else {
            return .blue
        }
    }
}

// MARK: - Expeditions Tab
struct GuildExpeditionsTab: View {
    let user: User
    let modelContext: ModelContext
    @State private var selectedExpedition: Expedition?
    @State private var selectedMembers: Set<UUID> = []
    @State private var showingExpeditionDetails = false
    @State private var showingActiveExpeditions = false
    @State private var now = Date()
    
    private let timer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()
    
    private var availableMembers: [GuildMember] {
        (user.guildMembers ?? []).filter { !$0.isOnExpedition && $0.isCombatant }
    }
    
    private var activeExpeditions: [ActiveExpedition] {
        user.activeExpeditions ?? []
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Active Expeditions Section
                if !activeExpeditions.isEmpty {
                    LiveActiveExpeditionsSection(
                        expeditions: activeExpeditions,
                        guildMembers: user.guildMembers ?? [],
                        now: now,
                        onComplete: { expedition in
                            GuildManager.shared.completeExpedition(expedition: expedition, for: user, context: modelContext)
                        }
                    )
                }
                
                // Available Expeditions Section
                AvailableExpeditionsSection(
                    availableMembers: availableMembers,
                    mode: .combat,
                    onExpeditionSelected: { expedition in
                        selectedExpedition = expedition
                        showingExpeditionDetails = true
                    }
                )
                
                // Guild Member Status
                GuildMemberStatusSection(
                    guildMembers: user.guildMembers ?? [],
                    activeExpeditions: activeExpeditions
                )
            }
            .padding()
        }
        .sheet(isPresented: $showingExpeditionDetails) {
            if let expedition = selectedExpedition {
                ExpeditionDetailView(
                    expedition: expedition,
                    availableMembers: availableMembers,
                    onLaunch: { selectedMembers in
                        GuildManager.shared.launchExpedition(
                            expeditionID: expedition.id,
                            with: Array(selectedMembers),
                            for: user,
                            context: modelContext
                        )
                        showingExpeditionDetails = false
                    }
                )
            }
        }
        .onAppear {
            // Check for completed expeditions
            GuildManager.shared.checkCompletedExpeditions(for: user, context: modelContext)
            // Clean up any invalid expeditions
            GuildManager.shared.cleanupInvalidExpeditions(for: user, context: modelContext)
        }
        .onReceive(timer) { newDate in
            self.now = newDate
            // Check for completed expeditions every second
            GuildManager.shared.checkCompletedExpeditions(for: user, context: modelContext)
            // Clean up any invalid expeditions periodically
            GuildManager.shared.cleanupInvalidExpeditions(for: user, context: modelContext)
        }
    }
}

// MARK: - Active Expeditions Section
struct LiveActiveExpeditionsSection: View {
    let expeditions: [ActiveExpedition]
    let guildMembers: [GuildMember]
    let now: Date
    let onComplete: (ActiveExpedition) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Active Expeditions")
                .font(.title2)
                .bold()
                .padding(.horizontal)
            
            ForEach(expeditions, id: \.id) { expedition in
                ActiveExpeditionCard(
                    expedition: expedition,
                    guildMembers: guildMembers,
                    onComplete: onComplete
                )
            }
        }
    }
}

struct ActiveExpeditionCard: View {
    let expedition: ActiveExpedition
    let guildMembers: [GuildMember]
    let onComplete: (ActiveExpedition) -> Void
    @State private var now = Date()
    
    private let timer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()
    
    private var expeditionData: Expedition? {
        ItemDatabase.shared.getExpedition(id: expedition.expeditionID)
    }
    
    private var progress: Double {
        guard let expeditionData = expeditionData else { return 0.0 }
        let totalDuration = expeditionData.duration
        let elapsed = now.timeIntervalSince(expedition.startTime)
        return min(elapsed / totalDuration, 1.0)
    }
    
    private var timeRemaining: String {
        guard let expeditionData = expeditionData else { return "Unknown" }
        let remaining = expedition.startTime.addingTimeInterval(expeditionData.duration).timeIntervalSince(now)
        if remaining <= 0 {
            return "Complete!"
        }
        
        let hours = Int(remaining) / 3600
        let minutes = Int(remaining) % 3600 / 60
        let seconds = Int(remaining) % 60
        
        if hours > 0 {
            return String(format: "%dh %02dm %02ds", hours, minutes, seconds)
        } else if minutes > 0 {
            return String(format: "%dm %02ds", minutes, seconds)
        } else {
            return String(format: "%ds", seconds)
        }
    }
    
    private var expeditionMembers: [GuildMember] {
        expedition.memberIDs.compactMap { id in
            guildMembers.first { $0.id == id }
        }
    }
    
    private var isCompleted: Bool {
        progress >= 1.0
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(expeditionData?.name ?? "Unknown Expedition")
                        .font(.headline)
                        .bold()
                        .foregroundColor(isCompleted ? .green : .primary)
                    
                    Text(expeditionData?.description ?? "Expedition details not available")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(timeRemaining)
                        .font(.caption)
                        .foregroundColor(isCompleted ? .green : .orange)
                        .bold()
                        .animation(.easeInOut(duration: 0.5), value: timeRemaining)
                    
                    if isCompleted {
                        Button("Claim Rewards") {
                            onComplete(expedition)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .tint(.green)
                    }
                }
            }
            
            // Progress Bar with live updates
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Progress")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(Int(progress * 100))%")
                        .font(.caption)
                        .bold()
                        .foregroundColor(isCompleted ? .green : .blue)
                }
                
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                    .tint(isCompleted ? .green : .blue)
                    .scaleEffect(x: 1, y: 1.5, anchor: .center)
            }
            
            // Member Icons
            HStack {
                Text("Members:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let firstRole = expeditionMembers.first?.role {
                    HStack(spacing: 4) {
                        Image(systemName: memberRoleIcon(for: firstRole))
                            .font(.caption2)
                            .foregroundColor(memberRoleColor(for: firstRole))
                        Text("×\(expeditionMembers.count)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(memberRoleColor(for: firstRole).opacity(0.2))
                    .cornerRadius(4)
                } else {
                    Text("None")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            // Rewards preview - Cleaned up to show just one icon per reward type
            if let expeditionData = expeditionData {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Rewards:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 8) {
                        // XP Reward
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .font(.caption)
                                .foregroundColor(.yellow)
                            Text("\(expeditionData.xpReward) XP")
                                .font(.caption)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(4)
                        
                        // Item Rewards - Single icon with summarized quantities
                        let groupedItems = groupedRewards(expeditionData.lootTable)
                        HStack(spacing: 4) {
                            Image(systemName: "bag.fill")
                                .font(.caption)
                                .foregroundColor(.green)
                            Text(lootSummaryText(groupedItems))
                                .font(.caption)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.2))
                        .cornerRadius(4)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Material.regular)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isCompleted ? Color.green.opacity(0.3) : Color.blue.opacity(0.3), lineWidth: 1)
                )
        )
        .onReceive(timer) { newDate in
            self.now = newDate
        }
    }
    
    private func groupedRewards(_ lootTable: [String: Int]) -> [String: Int] {
        var grouped: [String: Int] = [:]
        
        for (itemID, quantity) in lootTable {
            let baseName = formatItemName(itemID)
            if let existingQuantity = grouped[baseName] {
                grouped[baseName] = existingQuantity + quantity
            } else {
                grouped[baseName] = quantity
            }
        }
        
        return grouped
    }
    
    private func formatItemName(_ itemID: String) -> String {
        let name = itemID.replacingOccurrences(of: "item_", with: "")
            .replacingOccurrences(of: "material_", with: "")
            .replacingOccurrences(of: "equip_", with: "")
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
        return name
    }
    
    private func memberRoleIcon(for role: GuildMember.Role) -> String {
        switch role {
        case .forager: return "leaf.fill"
        case .gardener: return "drop.fill"
        case .alchemist: return "flask.fill"
        case .seer: return "eye.fill"
        case .blacksmith: return "hammer.fill"
        case .knight: return "shield.fill"
        case .archer: return "arrow.up.right"
        case .wizard: return "sparkles"
        case .rogue: return "bolt.fill"
        case .cleric: return "cross.fill"
        }
    }
    
    private func memberRoleColor(for role: GuildMember.Role) -> Color {
        switch role {
        case .forager, .gardener: return .green
        case .alchemist, .seer: return .purple
        case .blacksmith: return .orange
        case .knight, .cleric: return .blue
        case .archer, .rogue: return .gray
        case .wizard: return .indigo
        }
    }
    
    private func lootSummaryText(_ groupedItems: [String: Int], limit: Int? = nil) -> String {
        let sorted = groupedItems.sorted { $0.key < $1.key }
        let limited: ArraySlice<(key: String, value: Int)>
        if let limit = limit {
            limited = sorted.prefix(limit)
        } else {
            limited = sorted[sorted.startIndex..<sorted.endIndex]
        }
        var components = limited.map { "\($0.value)x \($0.key)" }
        if let limit = limit, sorted.count > limit {
            components.append("+\(sorted.count - limit) more")
        }
        return components.joined(separator: ", ")
    }
}

// MARK: - Available Expeditions Section
struct AvailableExpeditionsSection: View {
    let availableMembers: [GuildMember]
    let mode: ExpeditionMode
    let onExpeditionSelected: (Expedition) -> Void
    
    private var expeditions: [Expedition] {
        let all = ItemDatabase.shared.getAllExpeditions()
        switch mode {
        case .all:
            return all
        case .combat:
            return all.filter { expedition in
                guard let req = expedition.requiredRoles else { return true }
                return req.contains(where: { $0.isCombatantRole })
            }
        case .gathering:
            return all.filter { expedition in
                guard let req = expedition.requiredRoles else { return true }
                return req.contains(where: { $0.isGathererRole })
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Available Expeditions")
                .font(.title2)
                .bold()
                .padding(.horizontal)
            
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 280))], spacing: 16) {
                ForEach(expeditions, id: \.id) { expedition in
                    AvailableExpeditionCard(
                        expedition: expedition,
                        availableMembers: availableMembers,
                        onSelect: onExpeditionSelected
                    )
                }
            }
        }
    }
}

struct AvailableExpeditionCard: View {
    let expedition: Expedition
    let availableMembers: [GuildMember]
    let onSelect: (Expedition) -> Void
    
    private var canLaunch: Bool {
        availableMembers.count >= expedition.minMembers &&
        (expedition.requiredRoles?.isEmpty ?? true || 
         expedition.requiredRoles?.allSatisfy { role in
             availableMembers.contains { $0.role == role }
         } ?? true)
    }
    
    private var durationText: String {
        let hours = Int(expedition.duration) / 3600
        let minutes = Int(expedition.duration) % 3600 / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(expedition.name)
                        .font(.headline)
                        .bold()
                    
                    Text(expedition.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(durationText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(expedition.minMembers) members")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Requirements
            if let requiredRoles = expedition.requiredRoles, !requiredRoles.isEmpty {
                HStack {
                    Text("Requires:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    ForEach(requiredRoles, id: \.self) { role in
                        Text(role.rawValue)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(roleColor(for: role).opacity(0.2))
                            .cornerRadius(4)
                    }
                }
            }
            
            // Rewards Preview
            HStack {
                Text("Rewards:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("\(expedition.xpReward) XP")
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(4)
                
                // Single bag icon with summarized rewards
                let groupedItems = groupedRewards(expedition.lootTable)
                HStack(spacing: 4) {
                    Image(systemName: "bag.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                    Text(lootSummaryText(groupedItems, limit: 2))
                        .font(.caption)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.green.opacity(0.2))
                .cornerRadius(4)
            }
            
            Button(canLaunch ? "Launch Expedition" : "Insufficient Members") {
                onSelect(expedition)
            }
            .buttonStyle(.borderedProminent)
            .tint(canLaunch ? .blue : .gray)
            .disabled(!canLaunch)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Material.regular)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(canLaunch ? Color.blue.opacity(0.3) : Color.gray.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private func formatItemName(_ itemID: String) -> String {
        let name = itemID.replacingOccurrences(of: "item_", with: "")
            .replacingOccurrences(of: "material_", with: "")
            .replacingOccurrences(of: "equip_", with: "")
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
        return name
    }
    
    private func groupedRewards(_ lootTable: [String: Int]) -> [String: Int] {
        var grouped: [String: Int] = [:]
        for (itemID, quantity) in lootTable {
            let baseName = formatItemName(itemID)
            grouped[baseName, default: 0] += quantity
        }
        return grouped
    }

    private func lootSummaryText(_ groupedItems: [String: Int], limit: Int? = nil) -> String {
        let sorted = groupedItems.sorted { $0.key < $1.key }
        let itemsSlice: ArraySlice<(key: String, value: Int)>
        if let limit = limit { itemsSlice = sorted.prefix(limit) } else { itemsSlice = sorted[sorted.startIndex..<sorted.endIndex] }
        var parts = itemsSlice.map { "\($0.value)x \($0.key)" }
        if let limit = limit, sorted.count > limit { parts.append("+\(sorted.count - limit) more") }
        return parts.joined(separator: ", ")
    }
    
    private func roleColor(for role: GuildMember.Role) -> Color {
        switch role {
        case .forager, .gardener: return .green
        case .alchemist, .seer: return .purple
        case .blacksmith: return .orange
        case .knight, .cleric: return .blue
        case .archer, .rogue: return .gray
        case .wizard: return .indigo
        }
    }
}

// MARK: - Expedition Detail View
struct ExpeditionDetailView: View {
    let expedition: Expedition
    let availableMembers: [GuildMember]
    let onLaunch: (Set<UUID>) -> Void
    
    @State private var selectedQuantities: [GuildMember.Role: Int] = [:]
    @Environment(\.dismiss) private var dismiss
    
    private var groupedMembers: [GuildMember.Role: [GuildMember]] {
        Dictionary(grouping: availableMembers) { $0.role }
    }
    
    private var totalSelectedMembers: Int {
        selectedQuantities.values.reduce(0, +)
    }
    
    private var canLaunch: Bool {
        let hasMinMembers = totalSelectedMembers >= expedition.minMembers
        
        let hasRequiredRoles = expedition.requiredRoles?.allSatisfy { role in
            selectedQuantities[role, default: 0] > 0
        } ?? true
        
        return hasMinMembers && hasRequiredRoles
    }
    
    private var selectedMemberIDs: Set<UUID> {
        var ids: Set<UUID> = []
        for (role, quantity) in selectedQuantities {
            if let members = groupedMembers[role] {
                let selectedMembers = Array(members.prefix(quantity))
                ids.formUnion(selectedMembers.map { $0.id })
            }
        }
        return ids
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Expedition Info
                    VStack(alignment: .leading, spacing: 12) {
                        Text(expedition.name)
                            .font(.title)
                            .bold()
                        
                        Text(expedition.description)
                            .font(.body)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Label("\(Int(expedition.duration / 3600))h \(Int(expedition.duration.truncatingRemainder(dividingBy: 3600) / 60))m", systemImage: "clock")
                            Spacer()
                            Label("\(expedition.minMembers) min members", systemImage: "person.2")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Material.regular)
                    .cornerRadius(12)
                    
                    // Requirements
                    if let requiredRoles = expedition.requiredRoles, !requiredRoles.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Required Roles")
                                .font(.headline)
                            
                            ForEach(requiredRoles, id: \.self) { role in
                                HStack {
                                    Image(systemName: roleIcon(for: role))
                                        .foregroundColor(roleColor(for: role))
                                    Text(role.rawValue)
                                    Spacer()
                                    if selectedQuantities[role, default: 0] > 0 {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                    } else {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.red)
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                        }
                        .padding()
                        .background(Material.regular)
                        .cornerRadius(12)
                    }
                    
                    // Available Workers by Role
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Select Workers (\(totalSelectedMembers)/\(expedition.minMembers))")
                            .font(.headline)
                        
                        LazyVGrid(columns: [GridItem(.flexible())], spacing: 12) {
                            ForEach(GuildMember.Role.allCases, id: \.self) { role in
                                if let members = groupedMembers[role], !members.isEmpty {
                                    WorkerRoleCard(
                                        role: role,
                                        members: members,
                                        selectedQuantity: selectedQuantities[role, default: 0],
                                        onQuantityChanged: { quantity in
                                            selectedQuantities[role] = quantity
                                        }
                                    )
                                }
                            }
                        }
                    }
                    
                    // Rewards
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Rewards")
                            .font(.headline)
                        
                        HStack {
                            Label("\(expedition.xpReward) XP", systemImage: "star.fill")
                                .foregroundColor(.yellow)
                            Spacer()
                        }
                        
                        // Single bag icon with summarized items
                        let groupedItems = groupedRewards(expedition.lootTable)
                        HStack {
                            Label(lootSummaryText(groupedItems), systemImage: "bag.fill")
                                .foregroundColor(.green)
                            Spacer()
                        }
                    }
                    .padding()
                    .background(Material.regular)
                    .cornerRadius(12)
                }
                .padding()
            }
            .navigationTitle("Expedition Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Launch") {
                        onLaunch(selectedMemberIDs)
                    }
                    .disabled(!canLaunch)
                }
            }
        }
    }
    
    private func formatItemName(_ itemID: String) -> String {
        let name = itemID.replacingOccurrences(of: "item_", with: "")
            .replacingOccurrences(of: "material_", with: "")
            .replacingOccurrences(of: "equip_", with: "")
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
        return name
    }
    
    private func groupedRewards(_ lootTable: [String: Int]) -> [String: Int] {
        var grouped: [String: Int] = [:]
        for (itemID, quantity) in lootTable {
            let baseName = formatItemName(itemID)
            grouped[baseName, default: 0] += quantity
        }
        return grouped
    }

    private func lootSummaryText(_ groupedItems: [String: Int], limit: Int? = nil) -> String {
        let sorted = groupedItems.sorted { $0.key < $1.key }
        let itemsSlice: ArraySlice<(key: String, value: Int)>
        if let limit = limit { itemsSlice = sorted.prefix(limit) } else { itemsSlice = sorted[sorted.startIndex..<sorted.endIndex] }
        var parts = itemsSlice.map { "\($0.value)x \($0.key)" }
        if let limit = limit, sorted.count > limit { parts.append("+\(sorted.count - limit) more") }
        return parts.joined(separator: ", ")
    }
    
    private func roleIcon(for role: GuildMember.Role) -> String {
        switch role {
        case .forager: return "leaf.fill"
        case .gardener: return "drop.fill"
        case .alchemist: return "flask.fill"
        case .seer: return "eye.fill"
        case .blacksmith: return "hammer.fill"
        case .knight: return "shield.fill"
        case .archer: return "arrow.up.right"
        case .wizard: return "sparkles"
        case .rogue: return "bolt.fill"
        case .cleric: return "cross.fill"
        }
    }
    
    private func roleColor(for role: GuildMember.Role) -> Color {
        switch role {
        case .forager, .gardener: return .green
        case .alchemist, .seer: return .purple
        case .blacksmith: return .orange
        case .knight, .cleric: return .blue
        case .archer, .rogue: return .gray
        case .wizard: return .indigo
        }
    }
}

struct WorkerRoleCard: View {
    let role: GuildMember.Role
    let members: [GuildMember]
    let selectedQuantity: Int
    let onQuantityChanged: (Int) -> Void
    
    private var maxQuantity: Int {
        members.count
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: roleIcon(for: role))
                    .font(.title2)
                    .foregroundColor(roleColor(for: role))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(role.rawValue)
                        .font(.headline)
                        .bold()
                    
                    Text("\(members.count) available")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(selectedQuantity) selected")
                        .font(.subheadline)
                        .bold()
                        .foregroundColor(selectedQuantity > 0 ? .blue : .secondary)
                    
                    Text("of \(maxQuantity)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Quantity selector
            HStack(spacing: 12) {
                Button(action: {
                    if selectedQuantity > 0 {
                        onQuantityChanged(selectedQuantity - 1)
                    }
                }) {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                        .foregroundColor(selectedQuantity > 0 ? .red : .gray)
                }
                .disabled(selectedQuantity == 0)
                
                Text("\(selectedQuantity)")
                    .font(.title2)
                    .bold()
                    .frame(minWidth: 40)
                
                Button(action: {
                    if selectedQuantity < maxQuantity {
                        onQuantityChanged(selectedQuantity + 1)
                    }
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(selectedQuantity < maxQuantity ? .green : .gray)
                }
                .disabled(selectedQuantity == maxQuantity)
                
                Spacer()
                
                // Quick select buttons
                if maxQuantity > 1 {
                    Button("All") {
                        onQuantityChanged(maxQuantity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(selectedQuantity == maxQuantity)
                    
                    Button("None") {
                        onQuantityChanged(0)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(selectedQuantity == 0)
                }
            }
            
            // Selected members preview
            if selectedQuantity > 0 {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Selected Members:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 4) {
                        ForEach(Array(members.prefix(selectedQuantity)), id: \.id) { member in
                            HStack(spacing: 4) {
                                Image(systemName: "person.fill")
                                    .font(.caption)
                                    .foregroundColor(roleColor(for: role))
                                
                                Text(member.name)
                                    .font(.caption)
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(roleColor(for: role).opacity(0.2))
                            .cornerRadius(4)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Material.regular)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(selectedQuantity > 0 ? roleColor(for: role).opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }
    
    private func roleIcon(for role: GuildMember.Role) -> String {
        switch role {
        case .forager: return "leaf.fill"
        case .gardener: return "drop.fill"
        case .alchemist: return "flask.fill"
        case .seer: return "eye.fill"
        case .blacksmith: return "hammer.fill"
        case .knight: return "shield.fill"
        case .archer: return "arrow.up.right"
        case .wizard: return "sparkles"
        case .rogue: return "bolt.fill"
        case .cleric: return "cross.fill"
        }
    }
    
    private func roleColor(for role: GuildMember.Role) -> Color {
        switch role {
        case .forager, .gardener: return .green
        case .alchemist, .seer: return .purple
        case .blacksmith: return .orange
        case .knight, .cleric: return .blue
        case .archer, .rogue: return .gray
        case .wizard: return .indigo
        }
    }
}

struct MemberSelectionCard: View {
    let member: GuildMember
    let isSelected: Bool
    let onToggle: (Bool) -> Void
    
    var body: some View {
        Button {
            onToggle(!isSelected)
        } label: {
            VStack(spacing: 8) {
                Image(systemName: roleIcon(for: member.role))
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : roleColor(for: member.role))
                
                Text(member.name)
                    .font(.caption)
                    .bold()
                
                Text(member.role.rawValue)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Text("Lv. \(member.level)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? roleColor(for: member.role) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? roleColor(for: member.role) : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
    
    private func roleIcon(for role: GuildMember.Role) -> String {
        switch role {
        case .forager: return "leaf.fill"
        case .gardener: return "drop.fill"
        case .alchemist: return "flask.fill"
        case .seer: return "eye.fill"
        case .blacksmith: return "hammer.fill"
        case .knight: return "shield.fill"
        case .archer: return "arrow.up.right"
        case .wizard: return "sparkles"
        case .rogue: return "bolt.fill"
        case .cleric: return "cross.fill"
        }
    }
    
    private func roleColor(for role: GuildMember.Role) -> Color {
        switch role {
        case .forager, .gardener: return .green
        case .alchemist, .seer: return .purple
        case .blacksmith: return .orange
        case .knight, .cleric: return .blue
        case .archer, .rogue: return .gray
        case .wizard: return .indigo
        }
    }
}

// MARK: - Guild Member Status Section
struct GuildMemberStatusSection: View {
    let guildMembers: [GuildMember]
    let activeExpeditions: [ActiveExpedition]
    
    private var availableMembers: [GuildMember] {
        guildMembers.filter { !$0.isOnExpedition }
    }
    
    private var busyMembers: [GuildMember] {
        guildMembers.filter { $0.isOnExpedition }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Guild Member Status")
                .font(.title2)
                .bold()
                .padding(.horizontal)
            
            HStack(spacing: 20) {
                VStack {
                    Text("\(availableMembers.count)")
                        .font(.title)
                        .bold()
                        .foregroundColor(.green)
                    Text("Available")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack {
                    Text("\(busyMembers.count)")
                        .font(.title)
                        .bold()
                        .foregroundColor(.orange)
                    Text("On Expedition")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack {
                    Text("\(activeExpeditions.count)")
                        .font(.title)
                        .bold()
                        .foregroundColor(.blue)
                    Text("Active")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Material.regular)
            .cornerRadius(12)
        }
    }
}

// MARK: - Projects Tab
struct GuildProjectsTab: View {
    let user: User
    let guild: Guild?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Guild Projects coming soon!")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            .padding()
        }
    }
}

struct StartHuntView: View {
    let user: User
    let modelContext: ModelContext
    
    private let availableEnemies = [
        ("Goblin", "tortoise.fill", Color.green, "enemy_goblin", 1),
        ("Zombie", "bandage.fill", Color.purple, "enemy_zombie", 2),
        ("Spider", "ant.fill", Color.brown, "enemy_spider", 3),
        ("Skeleton", "skull.fill", Color.gray, "enemy_skeleton", 4),
        ("Ghost", "sparkles", Color.blue, "enemy_ghost", 5),
        ("Dragon", "flame.fill", Color.red, "enemy_dragon", 10)
    ]
    
    private var availableCombatants: [GuildMember] {
        (user.guildMembers ?? []).filter { $0.isCombatant }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Available hunters
                VStack(alignment: .leading, spacing: 12) {
                    Text("Available Hunters")
                        .font(.headline)
                    
                    if availableCombatants.isEmpty {
                        Text("No combat-ready hunters available")
                            .foregroundColor(.secondary)
                            .italic()
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 12) {
                            ForEach(availableCombatants, id: \.id) { member in
                                HunterCard(member: member)
                            }
                        }
                    }
                }
                
                // Available enemies
                VStack(alignment: .leading, spacing: 12) {
                    Text("Available Targets")
                        .font(.headline)
                    
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 160))], spacing: 12) {
                        ForEach(availableEnemies, id: \.0) { enemy in
                            EnemyCard(
                                name: enemy.0,
                                icon: enemy.1,
                                color: enemy.2,
                                enemyID: enemy.3,
                                difficulty: enemy.4,
                                onStart: { startHunt(enemyID: enemy.3) }
                            )
                        }
                    }
                }
            }
            .padding()
        }
    }
    
    private func startHunt(enemyID: String) {
        let combatantIDs = availableCombatants.map { $0.id }
        guard !combatantIDs.isEmpty else { return }
        
        let hunt = ActiveHunt(enemyID: enemyID, memberIDs: combatantIDs, owner: user)
        modelContext.insert(hunt)
        user.activeHunts?.append(hunt)
    }
}

struct HunterCard: View {
    let member: GuildMember
    
    private var roleIcon: String {
        switch member.role {
        case .knight: return "shield.fill"
        case .archer: return "arrow.up.right"
        case .wizard: return "sparkles"
        case .rogue: return "bolt.fill"
        case .cleric: return "cross.fill"
        default: return "person.fill"
        }
    }
    
    private var roleColor: Color {
        switch member.role {
        case .knight: return .blue
        case .archer: return .gray
        case .wizard: return .purple
        case .rogue: return .orange
        case .cleric: return .green
        default: return .secondary
        }
    }
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: roleIcon)
                .font(.title2)
                .foregroundColor(roleColor)
            
            Text(member.name)
                .font(.subheadline.bold())
            
            Text("\(member.role.rawValue) Lv.\(member.level)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text("\(Int(member.combatDPS())) DPS")
                .font(.caption)
                .foregroundColor(.blue)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Material.thin)
        .cornerRadius(8)
    }
}

struct EnemyCard: View {
    let name: String
    let icon: String
    let color: Color
    let enemyID: String
    let difficulty: Int
    let onStart: () -> Void
    
    private var difficultyText: String {
        switch difficulty {
        case 1: return "Easy"
        case 2: return "Medium"
        case 3: return "Hard"
        case 4: return "Expert"
        case 5: return "Master"
        default: return "Legendary"
        }
    }
    
    private var difficultyColor: Color {
        switch difficulty {
        case 1: return .green
        case 2: return .yellow
        case 3: return .orange
        case 4: return .red
        case 5: return .purple
        default: return .black
        }
    }
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(name)
                .font(.subheadline.bold())
            
            Text(difficultyText)
                .font(.caption)
                .foregroundColor(difficultyColor)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(difficultyColor.opacity(0.2))
                .cornerRadius(4)
            
            Button("Start Hunt") {
                onStart()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Material.thin)
        .cornerRadius(8)
    }
}

struct RecentActivityCard: View {
    let user: User
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Activity")
                .font(.headline)
            
            if user.huntKillTally.isEmpty {
                Text("No recent activity")
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                ForEach(Array(user.huntKillTally.prefix(3)), id: \.key) { enemyID, kills in
                    HStack {
                        Text(enemyID.replacingOccurrences(of: "enemy_", with: "").capitalized)
                            .font(.subheadline)
                        
                        Spacer()
                        
                        Text("\(kills) kills")
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
}

struct GuildPerksCard: View {
    let guild: Guild
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Guild Perks")
                .font(.headline)
            
            ForEach(guild.unlockedPerks, id: \.self) { perk in
                HStack {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                    
                    Text(perk.description)
                        .font(.subheadline)
                    
                    Spacer()
                }
            }
        }
        .padding()
        .background(Material.regular)
        .cornerRadius(12)
    }
}

// MARK: - GuildMember.Role Extensions
extension GuildMember.Role {
    var hasSpecialAbility: Bool {
        switch self {
        case .forager, .gardener, .alchemist, .seer, .blacksmith:
            return true
        default:
            return false
        }
    }
    
    var specialAbilityDescription: String {
        switch self {
        case .forager:
            return "Finds materials"
        case .gardener:
            return "Auto-harvests"
        case .alchemist:
            return "Brews potions"
        case .seer:
            return "Boosts echoes"
        case .blacksmith:
            return "Crafts items"
        default:
            return ""
        }
    }
}
