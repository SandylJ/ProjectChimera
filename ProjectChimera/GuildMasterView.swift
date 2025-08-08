
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
                .navigationTitle("Guild Hall")
                .navigationTitle("Guild Hall")
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
            
            Text("Loading Guild Hall...")
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Active Hunts")
                    .font(.headline)
                
                Spacer()
                
                if user.unclaimedHuntGold > 0 {
                    Button("Claim \(user.unclaimedHuntGold) Gold") {
                        GuildManager.shared.claimHuntRewards(for: user)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
            
            if let activeHunts = user.activeHunts, !activeHunts.isEmpty {
                ForEach(activeHunts) { hunt in
                    HuntProgressRow(hunt: hunt, user: user)
                }
            } else {
                Text("No active hunts")
                    .foregroundColor(.secondary)
                    .italic()
            }
            
            Divider()
            
            Text("Start New Hunt")
                .font(.subheadline.bold())
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                HuntButton(title: "Goblin", icon: "tortoise.fill", color: .green) {
                    startHunt(enemyID: "enemy_goblin")
                }
                
                HuntButton(title: "Zombie", icon: "bandage.fill", color: .purple) {
                    startHunt(enemyID: "enemy_zombie")
                }
                
                HuntButton(title: "Spider", icon: "ant.fill", color: .brown) {
                    startHunt(enemyID: "enemy_spider")
                }
                
                HuntButton(title: "Dragon", icon: "flame.fill", color: .red) {
                    startHunt(enemyID: "enemy_dragon")
                }
            }
        }
        .padding()
        .background(Material.regular)
        .cornerRadius(12)
    }
    
    private func startHunt(enemyID: String) {
        let combatantIDs = (user.guildMembers ?? []).filter { $0.isCombatant }.map { $0.id }
        guard !combatantIDs.isEmpty else { return }
        GuildManager.shared.startHunt(enemyID: enemyID, with: combatantIDs, for: user, context: modelContext)
    }
}

struct HuntButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Material.thin)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

struct HuntProgressRow: View {
    let hunt: ActiveHunt
    let user: User
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(hunt.enemyID.replacingOccurrences(of: "enemy_", with: "").capitalized)
                    .font(.subheadline.bold())
                
                Text("\(hunt.killsAccumulated) kills")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(hunt.memberIDs.count) members")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("Active")
                    .font(.caption2)
                    .foregroundColor(.green)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.green.opacity(0.2))
                    .cornerRadius(4)
            }
        }
        .padding(.vertical, 4)
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
                        .font(.caption)
                    
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
                
                // Current Members
                CurrentMembersSection(guildMembers: guildMembers, user: user, modelContext: modelContext)
            }
            .padding()
        }
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
                ForEach(GuildMember.Role.allCases, id: \.self) { role in
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
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Expeditions coming soon!")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            .padding()
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
