import SwiftUI
import SwiftData

struct QuestsView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var user: User

    @State private var showRewardPopup = false
    @State private var lastQuestRewards: [LootReward] = []
    @State private var selectedView: ViewMode = .board

    enum ViewMode: String, CaseIterable, Identifiable {
        var id: String { rawValue }
        case board = "Board"
        case log = "Completion Log"
    }

    private var activeQuests: [Quest] { user.quests?.filter { $0.status == .active } ?? [] }
    private var availableQuests: [Quest] { user.quests?.filter { $0.status == .available } ?? [] }
    private var completedQuests: [Quest] { user.quests?.filter { $0.status == .completed } ?? [] }

    var body: some View {
        ZStack {
            GameTheme.bgGradient.ignoresSafeArea()
            SparkleField().opacity(0.35).ignoresSafeArea()

            VStack(spacing: 20) {
                header
                Picker("Mode", selection: $selectedView) {
                    ForEach(ViewMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 4)
                .padding(.bottom, 8)

                ScrollView {
                    switch selectedView {
                    case .board:
                        boardContent
                    case .log:
                        completionLog
                    }
                }
                .padding(.bottom, 8)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("Quest Board")
        .sheet(isPresented: $showRewardPopup) {
            QuestRewardPopup(rewards: $lastQuestRewards, isPresented: $showRewardPopup)
        }
        .onAppear {
            QuestManager.shared.initializeQuests(for: user, context: modelContext)
        }
    }

    private var header: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(colors: [.purple.opacity(0.45), .blue.opacity(0.45)], startPoint: .topLeading, endPoint: .bottomTrailing)
                .frame(height: 170)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .overlay(
                    ZStack {
                        Image(systemName: "scroll.fill").font(.system(size: 72)).foregroundStyle(.ultraThinMaterial).offset(x: 130, y: -16)
                        Image(systemName: "sparkles").font(.system(size: 64)).foregroundStyle(.ultraThinMaterial).offset(x: -110, y: 18)
                    }
                )
            VStack(alignment: .leading, spacing: 10) {
                Text("The Quest Board").font(.title.bold()).foregroundStyle(.white)
                HStack(spacing: 16) {
                    Chip(text: "Active: \(activeQuests.count)")
                    Chip(text: "Available: \(availableQuests.count)")
                    Chip(text: "Completed: \(completedQuests.count)")
                }
            }
            .padding()
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    // MARK: - Board
    private var boardContent: some View {
        VStack(alignment: .leading, spacing: 36) {
            if !completedQuests.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Ready to Claim").font(.title3.bold()).padding(.horizontal)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(completedQuests) { quest in
                                QuestCardSpectacular(quest: quest, user: user, onPrimary: {
                                    lastQuestRewards = quest.rewards
                                    QuestManager.shared.claimQuestReward(for: quest, on: user, context: modelContext)
                                    showRewardPopup = true
                                })
                                .frame(width: 300)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("In Progress").font(.title3.bold()).padding(.horizontal)
                if activeQuests.isEmpty {
                    GlassCard { EmptyView() }
                        .overlay(
                            VStack(spacing: 10) {
                                Text("No active quests yet").foregroundStyle(GameTheme.textPrimary)
                                Text("Accept a quest from below to begin!").font(.caption).foregroundStyle(GameTheme.textSecondary)
                            }
                            .padding()
                        )
                        .padding(.horizontal)
                } else {
                    VStack(spacing: 18) {
                        ForEach(activeQuests) { quest in
                            QuestCardSpectacular(quest: quest, user: user, onPrimary: { })
                                .padding(.horizontal)
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Available Quests").font(.title3.bold()).padding(.horizontal)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 340), spacing: 20)], spacing: 22) {
                    ForEach(availableQuests) { quest in
                        QuestCardSpectacular(quest: quest, user: user, onPrimary: { })
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
        }
        .padding(.vertical)
    }

    // MARK: - Completion Log
    private var completionLog: some View {
        let achievements = (user.achievements ?? []).sorted { $0.dateEarned > $1.dateEarned }
        let questCompletions = achievements.filter { $0.title.hasPrefix("Completed:") }

        return VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 14) {
                GlassCard {
                    EmptyView()
                }
                .overlay(
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: "trophy.fill").foregroundStyle(.yellow)
                            Text("Achievements").font(.headline).foregroundStyle(GameTheme.textPrimary)
                            Spacer()
                            Text("\(achievements.count)")
                                .font(.system(.headline, design: .rounded)).foregroundStyle(GameTheme.textSecondary)
                        }
                        ProgressBar(progress: min(CGFloat(questCompletions.count) / 10.0, 1.0))
                        Text("Quest completions: \(questCompletions.count)").font(.caption).foregroundStyle(GameTheme.textSecondary)
                    }
                    .padding()
                )
            }
            .padding(.horizontal)

            if achievements.isEmpty {
                GlassCard { EmptyView() }
                    .overlay(
                        VStack(spacing: 10) {
                            Text("No achievements yet").foregroundStyle(GameTheme.textPrimary)
                            Text("Finish quests to fill your Hall of Fame!").font(.caption).foregroundStyle(GameTheme.textSecondary)
                        }
                        .padding()
                    )
                    .padding(.horizontal)
            } else {
                VStack(spacing: 16) {
                    ForEach(achievements) { achievement in
                        AchievementRowView(achievement: achievement)
                            .padding(.horizontal)
                    }
                }
            }
        }
        .padding(.vertical)
    }
}

// MARK: - Spectacular Quest Card
private struct QuestCardSpectacular: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var quest: Quest
    @Bindable var user: User
    var onPrimary: () -> Void

    private var categoryChips: [String] {
        switch quest.type {
        case .milestone(let category, _): return [category.rawValue.capitalized]
        case .streak(let category, _): return [category.rawValue.capitalized, "Streak"]
        case .exploration(let categories): return categories.map { $0.rawValue.capitalized }
        }
    }

    private var progressTuple: (current: Int, target: Int) {
        switch quest.type {
        case .milestone(_, let count): return (quest.progress, count)
        case .streak(_, let days): return (quest.progress, days)
        case .exploration(let categories): return (quest.progress, max(categories.count, 1))
        }
    }

    var body: some View {
        GlassCard {
            EmptyView()
        }
        .overlay(
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(quest.title)
                            .font(.headline)
                            .foregroundStyle(GameTheme.textPrimary)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                        Text(quest.questDescription)
                            .font(.caption)
                            .foregroundStyle(GameTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(categoryChips, id: \.self) { Chip(text: $0) }
                            }
                        }
                    }
                    .layoutPriority(1)
                    Spacer()
                    Image(systemName: iconForQuest())
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(10)
                        .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 10))
                }

                if quest.status != .available {
                    let p = progressTuple
                    VStack(alignment: .leading, spacing: 8) {
                        ProgressBar(progress: max(0, min(CGFloat(p.current) / CGFloat(max(p.target, 1)), 1)))
                        Text("Progress: \(p.current)/\(p.target)").font(.caption).foregroundStyle(GameTheme.textSecondary)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Rewards").font(.caption.bold()).foregroundStyle(GameTheme.textSecondary)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], spacing: 10) {
                        ForEach(quest.rewards) { reward in
                            RewardPill(reward: reward)
                        }
                    }
                }

                HStack(spacing: 14) {
                    switch quest.status {
                    case .available:
                        Button {
                            quest.status = .active
                            try? modelContext.save()
                        } label: { Text("Accept Quest") }
                            .buttonStyle(GlowButtonStyle())
                    case .active:
                        Chip(text: "In Progress")
                        Spacer()
                    case .completed:
                        Button { onPrimary() } label: { Text("Claim Reward") }
                            .buttonStyle(GlowButtonStyle(gradient: LinearGradient(colors: [.green, .mint], startPoint: .topLeading, endPoint: .bottomTrailing)))
                    }
                    Spacer()
                }
            }
            .padding(18)
            .frame(minHeight: 220)
        )
    }

    private func iconForQuest() -> String {
        switch quest.type {
        case .milestone(let c, _): return iconForCategory(c)
        case .streak(let c, _): return iconForCategory(c)
        case .exploration(_): return "map.fill"
        }
    }

    private func iconForCategory(_ c: SkillCategory) -> String {
        switch c {
        case .strength: return "bolt.fill"
        case .mind: return "brain.head.profile"
        case .joy: return "face.smiling.fill"
        case .vitality: return "heart.fill"
        case .awareness: return "eye.fill"
        case .flow: return "wind"
        case .finance: return "dollarsign.circle.fill"
        case .other: return "sparkles"
        }
    }
}

// MARK: - Rewards, Achievements, Utilities
private struct RewardPill: View {
    let reward: LootReward
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundStyle(color)
            Text(label)
                .font(.footnote.bold())
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .padding(.vertical, 8).padding(.horizontal, 12)
        .background(.white.opacity(0.10), in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.12)))
    }
    private var label: String {
        switch reward {
        case .currency(let amount): return "\(amount) Gold"
        case .item(let id, let quantity):
            if let item = ItemDatabase.shared.getItem(id: id) { return "\(item.name) x\(quantity)" }
            return "Item x\(quantity)"
        case .experienceBurst(let skill, let amount): return "+\(amount) \(skill.rawValue.capitalized) XP"
        case .runes(let amount): return "\(amount) Runes"
        case .echoes(let amount): return String(format: "%.0f Echoes", amount)
        }
    }
    private var icon: String {
        switch reward {
        case .currency(_): return "creditcard.circle.fill"
        case .item(_, _): return "shippingbox.fill"
        case .experienceBurst(_, _): return "sparkles"
        case .runes(_): return "circle.hexagonpath.fill"
        case .echoes(_): return "waveform"
        }
    }
    private var color: Color {
        switch reward {
        case .currency(_): return .yellow
        case .item(_, _): return .blue
        case .experienceBurst(_, _): return .purple
        case .runes(_): return .cyan
        case .echoes(_): return .gray
        }
    }
}

private struct AchievementRowView: View {
    @Bindable var achievement: Achievement
    var body: some View {
        GlassCard { EmptyView() }
            .overlay(
                HStack(alignment: .center, spacing: 16) {
                    Image(systemName: achievement.title.hasPrefix("Completed:") ? "checkmark.seal.fill" : "trophy.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(achievement.title.hasPrefix("Completed:") ? .green : .yellow)
                        .padding(10)
                        .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 10))
                    VStack(alignment: .leading, spacing: 6) {
                        Text(achievement.title).font(.headline).foregroundStyle(GameTheme.textPrimary)
                        Text(achievement.achievementDescription).font(.caption).foregroundStyle(GameTheme.textSecondary)
                    }
                    Spacer()
                    Text(shortDate(achievement.dateEarned)).font(.caption).foregroundStyle(GameTheme.textSecondary)
                }
                .padding(14)
            )
    }
    private func shortDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f.string(from: date)
    }
}

private struct WrapHStack<Content: View>: View {
    let spacing: CGFloat
    let content: Content
    init(spacing: CGFloat = 8, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }
    var body: some View {
        FlowLayout(alignment: .leading, spacing: spacing) { content }
    }
}

// A minimal flow layout for wrapping content
private struct FlowLayout<Content: View>: View {
    let alignment: HorizontalAlignment
    let spacing: CGFloat
    @ViewBuilder var content: () -> Content

    var body: some View {
        var width: CGFloat = 0
        var height: CGFloat = 0
        return GeometryReader { geometry in
            var elements: [Int: CGRect] = [:]
            ZStack(alignment: Alignment(horizontal: alignment, vertical: .top)) {
                content()
                    .alignmentGuide(.leading) { d in
                        if abs(width - d.width) > geometry.size.width {
                            width = 0; height -= d.height + spacing
                        }
                        let result = width
                        if Int(elements.count) >= 0 { elements[elements.count] = CGRect(x: width, y: height, width: d.width, height: d.height) }
                        width -= d.width + spacing
                        return result
                    }
                    .alignmentGuide(.top) { d in
                        let result = height
                        return result
                    }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// Reuse existing reward popup
struct QuestRewardPopup: View {
    @Binding var rewards: [LootReward]
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 20) {
            Text("Quest Complete!")
                .font(.largeTitle).bold()
            Text("You earned:")
                .font(.headline)
            ForEach(rewards) { reward in
                RewardPill(reward: reward)
                    .font(.title3)
            }
            Button("Awesome!") { isPresented = false }
                .buttonStyle(GlowButtonStyle())
        }
        .padding()
    }
}
