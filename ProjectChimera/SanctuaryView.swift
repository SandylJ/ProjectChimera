import SwiftUI
import SwiftData

struct SanctuaryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var users: [User]
    private var user: User? { users.first }
    
    @State private var didLevelUp = false
    @State private var didEvolve = false

    var body: some View {
        NavigationView {
            ZStack {
                if let user = user {
                    ScrollView {
                        VStack(spacing: 16) {
                            // Epic hero header
                            SanctuaryHeroHeader(user: user)
                            
                            // Feature tiles
                            SanctuaryFeatureGrid(user: user, didLevelUp: $didLevelUp, didEvolve: $didEvolve)

                            if let challenges = user.challenges, !challenges.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Weekly Challenges")
                                        .font(.title2).bold()
                                        .padding(.horizontal)
                                    ForEach(challenges) { challenge in
                                        ChallengeRowView(challenge: challenge)
                                    }
                                }
                            }
                        }
                        .padding(.vertical)
                    }
                    .navigationTitle("Sanctuary")
                    .onAppear {
                        // Initialize systems for the user if they haven't been already.
                        ObsidianGymnasiumManager.shared.initializeStatues(for: user, context: modelContext)
                        QuestManager.shared.initializeQuests(for: user, context: modelContext)
                        GuildManager.shared.initializeGuild(for: user, context: modelContext)
                        GuildManager.shared.generateDailyBounties(for: user, context: modelContext)
                        IdleGameManager.shared.processOfflineHunts(for: user, context: modelContext)
                    }
                } else {
                    ContentUnavailableView("Loading...", systemImage: "hourglass")
                }

                LevelUpOverlay(didLevelUp: $didLevelUp)
            }
        }
    }
    

}

private struct SanctuaryHeroHeader: View {
    @Bindable var user: User
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(colors: [.purple.opacity(0.4), .blue.opacity(0.4)], startPoint: .topLeading, endPoint: .bottomTrailing)
                .frame(maxWidth: .infinity)
                .frame(height: 180)
                .cornerRadius(18)
                .overlay(
                    ZStack {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 80))
                            .foregroundStyle(.ultraThinMaterial)
                            .offset(x: 120, y: -30)
                        Image(systemName: "tree.fill")
                            .font(.system(size: 80))
                            .foregroundStyle(.ultraThinMaterial)
                            .offset(x: -80, y: 10)
                    }
                )
            VStack(alignment: .leading, spacing: 4) {
                Text("The Sanctuary")
                    .font(.largeTitle).bold()
                    .foregroundColor(.white)
                Text("Heart of your journey. Tend, grow, and ascend.")
                    .foregroundColor(.white.opacity(0.9))
                    .font(.callout)
            }
            .padding()
        }
        .padding(.horizontal)
    }
}

private struct SanctuaryFeatureGrid: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var user: User
    @Binding var didLevelUp: Bool
    @Binding var didEvolve: Bool
    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 16)], spacing: 16) {
            NavigationLink(destination: LairView()) { FeatureTile(title: "Chimera's Lair", subtitle: "Evolve your companion", systemImage: "pawprint.fill", color: .teal) }
            NavigationLink(destination: JournalView(didLevelUp: $didLevelUp, didEvolve: $didEvolve)) { FeatureTile(title: "Journal", subtitle: "Reflect for XP", systemImage: "book.closed.fill", color: .brown) }
            NavigationLink(destination: GuildMasterView(user: user)) { FeatureTile(title: "Guild Master", subtitle: "Hunts, Bounties, Mercs", systemImage: "person.text.rectangle", color: .indigo) }
            NavigationLink(destination: AltarOfWhispersView(user: user)) { FeatureTile(title: "Altar of Whispers", subtitle: "Echoes, Runes, Gold", systemImage: "flame.fill", color: .orange) }
            NavigationLink(destination: HabitGardenView(user: user)) { FeatureTile(title: "Habit Garden", subtitle: "Grow rewards over time", systemImage: "leaf.fill", color: .green) }
            NavigationLink(destination: GuildHallView(user: user)) { FeatureTile(title: "Guild Hall", subtitle: "Manage your ranks", systemImage: "person.3.fill", color: .blue) }
            NavigationLink(destination: ObsidianGymnasiumView(user: user)) { FeatureTile(title: "Obsidian Gymnasium", subtitle: "Chisel will into stone", systemImage: "figure.strengthtraining.traditional", color: .purple) }
        }
        .padding(.horizontal)
    }
}

private struct FeatureTile: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let color: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 28, weight: .semibold))
                .foregroundColor(.white)
                .padding(10)
                .background(color.opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            Text(title)
                .font(.headline)
            Text(subtitle)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 100, alignment: .leading)
        .background(Material.regular)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Obsidian Gymnasium View

struct ObsidianGymnasiumView: View {
    @Bindable var user: User
    
    // Session-scoped UI state
    @State private var showRewardBanner = false
    @State private var lastRewardText = ""
    @State private var chiselAmount: Double = 25
    @State private var logs: [WillpowerLog] = []
    @State private var countInputs: [String: String] = [:] // actionID -> amount string
    @StateObject private var hkManager = HealthKitManager()
    @State private var healthAuthorized = false
    @State private var didClaimStepsToday = false
    @State private var didClaimWorkoutsToday = false
    @State private var didClaimMindfulToday = false
    
    // Actions
    private var countBasedActions: [CountAction] {
        [
            .init(id: "pushups", name: "Push‑ups", unit: "rep", pointsPerUnit: 1, color: .orange, icon: "figure.pushup"),
            .init(id: "squats", name: "Squats", unit: "rep", pointsPerUnit: 1, color: .red, icon: "figure.strengthtraining.traditional"),
            .init(id: "walk", name: "Walking Pad", unit: "min", pointsPerUnit: 1, color: .green, icon: "figure.walk"),
            .init(id: "plank", name: "Plank Hold", unit: "10s", pointsPerUnit: 1, color: .teal, icon: "figure.core.training"),
            .init(id: "meditate", name: "Meditation", unit: "min", pointsPerUnit: 2, color: .purple, icon: "brain.head.profile")
        ]
    }
    private var tapActions: [TapAction] {
        [
            .init(id: "resist_snack", name: "Resisted Snack", points: 5, color: .pink, icon: "fork.knife"),
            .init(id: "hydrate", name: "Hydrate 8oz", points: 2, color: .cyan, icon: "drop.fill"),
            .init(id: "cold_shower", name: "Cold Shower min", points: 3, color: .blue, icon: "snowflake"),
            .init(id: "pomodoro", name: "Pomodoro 25m", points: 20, color: .mint, icon: "timer"),
            .init(id: "digital_detox", name: "No Social 15m", points: 5, color: .indigo, icon: "wifi.slash")
        ]
    }
    
    private var currentStatue: Statue? {
        user.statues?.first { $0.id == user.currentStatueID }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerCard
                
                if let statue = currentStatue {
                    statueCard(statue: statue)
                } else {
                    finishedAllStatuesCard
                }
                
                willpowerActionsSection
                
                healthSyncSection
                
                if !logs.isEmpty { sessionLogSection }
            }
            .padding(.vertical)
        }
        .navigationTitle("Gymnasium")
        .overlay(alignment: .top) {
            if showRewardBanner {
                Text(lastRewardText)
                    .font(.headline)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 16)
                    .background(Color.green.opacity(0.95))
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(radius: 10, y: 6)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.3) {
                            withAnimation { showRewardBanner = false }
                        }
                    }
                    .padding(.top, 10)
            }
        }
    }
    
    // MARK: - Header / HUD
    private var headerCard: some View {
        VStack(spacing: 10) {
            HStack(alignment: .center) {
                Image(systemName: "hexagon.fill").foregroundColor(.purple).font(.title2)
                Text("Willpower")
                    .font(.title3.bold())
                Spacer()
                Text("\(user.willpower)")
                    .font(.system(.title2, design: .rounded).weight(.heavy))
                    .monospacedDigit()
                    .foregroundColor(.purple)
            }
            .padding(12)
            .background(Material.regular)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            
            if let passive = passiveWillpowerInfo {
                HStack(spacing: 8) {
                    Image(systemName: "bolt.heart.fill").foregroundColor(.yellow)
                    Text("Passive: +\(passive.amount)/min for \(passive.remaining)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
        }
        .padding(.horizontal)
    }
    
    private var passiveWillpowerInfo: (amount: Int, remaining: String)? {
        for (effect, expiry) in user.activeBuffs {
            if case .willpowerGeneration(let amount) = effect {
                let remaining = max(0, Int(expiry.timeIntervalSince(Date())))
                let mins = remaining / 60
                let secs = remaining % 60
                return (amount, String(format: "%dm %02ds", mins, secs))
            }
        }
        return nil
    }
    
    // MARK: - Statue Card
    @ViewBuilder
    private func statueCard(statue: Statue) -> some View {
        VStack(spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(statue.name).font(.title3.bold())
                    Text(statue.statueDescription).font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                ChipView(text: statue.isComplete ? "Complete" : "Carving")
            }
            
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.gray.opacity(0.15))
                    .frame(height: 160)
                    .overlay(Image(systemName: "figure.stand").resizable().scaledToFit().foregroundColor(.black.opacity(0.25)).padding(24))
                let fillHeight = max(0.0, min(1.0, statue.progress))
                GeometryReader { geo in
                    Image(systemName: "figure.stand")
                        .resizable()
                        .scaledToFit()
                        .foregroundColor(.purple.opacity(0.9))
                        .frame(width: geo.size.width)
                        .mask(
                            Rectangle()
                                .frame(width: geo.size.width, height: geo.size.height * fillHeight)
                                .offset(y: geo.size.height * (1 - fillHeight))
                        )
                        .animation(.easeInOut(duration: 0.35), value: statue.progress)
                }
                .frame(height: 160)
            }
            .clipShape(RoundedRectangle(cornerRadius: 14))
            
            VStack(spacing: 6) {
                ProgressView(value: statue.progress)
                    .progressViewStyle(LinearProgressViewStyle(tint: .purple))
                Text("\(statue.currentWillpower) / \(statue.requiredWillpower) Willpower")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if statue.isComplete {
                Button {
                    if let context = user.modelContext {
                        withAnimation {
                            ObsidianGymnasiumManager.shared.completeStatue(for: user, context: context)
                            lastRewardText = "Statue Complete! Reward applied."
                            showRewardBanner = true
                        }
                    }
                } label: {
                    Label("Claim Reward & Begin Next", systemImage: "sparkles")
                }
                .buttonStyle(JuicyButtonStyle())
                .tint(.green)
            } else {
                chiselControls(statue: statue)
            }
        }
        .padding()
        .background(Material.regular)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private func chiselControls(statue: Statue) -> some View {
        VStack(spacing: 10) {
            HStack {
                Label("Chisel Amount", systemImage: "hammer")
                    .font(.subheadline.bold())
                Spacer()
                Text("\(Int(chiselAmount))")
                    .font(.subheadline.monospacedDigit())
                    .foregroundColor(.purple)
            }
            Slider(value: $chiselAmount, in: 1...Double(max(1, user.willpower)), step: 1)
            HStack(spacing: 10) {
                Button { chisel(Int(min(10, user.willpower))) } label: { Text("10") }
                    .buttonStyle(.bordered)
                Button { chisel(Int(min(50, user.willpower))) } label: { Text("50") }
                    .buttonStyle(.bordered)
                Button { chisel(Int(min(200, user.willpower))) } label: { Text("200") }
                    .buttonStyle(.bordered)
                Spacer()
                Button { chisel(Int(min(Int(chiselAmount), user.willpower))) } label: {
                    HStack { Image(systemName: "hammer.fill"); Text("Chisel") }
                }
                .buttonStyle(JuicyButtonStyle())
                .disabled(user.willpower <= 0)
            }
        }
    }
    
    private func chisel(_ amount: Int) {
        guard amount > 0 else { return }
        let before = user.willpower
        withAnimation {
            ObsidianGymnasiumManager.shared.chiselStatue(for: user, amount: amount)
        }
        let spent = before - user.willpower
        if spent > 0 {
            lastRewardText = "Chiseled \(spent) Willpower into stone."
            showRewardBanner = true
            SensoryFeedbackManager.shared.trigger(for: .taskCompleted)
        }
    }
    
    // MARK: - Willpower Actions
    private var willpowerActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Willpower Actions").font(.title3.bold()).padding(.horizontal)
            
            // Tap actions grid
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 12)], spacing: 12) {
                ForEach(tapActions) { action in
                    Button {
                        earnWillpower(action.points, reason: action.name)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: action.icon).foregroundColor(.white)
                            Text("+\(action.points)")
                                .font(.headline.monospacedDigit())
                                .foregroundColor(.white)
                            Spacer(minLength: 0)
                        }
                        .padding(12)
                        .background(action.color.opacity(0.8))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            VStack(alignment: .leading, spacing: 2) {
                                Text(action.name)
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.9))
                                    .lineLimit(1)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding([.leading, .bottom], 8)
                            , alignment: .bottomLeading
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            
            // Count-based rows
            VStack(spacing: 10) {
                ForEach(countBasedActions) { action in
                    countRow(for: action)
                }
            }
            .padding(.horizontal)
        }
    }
    
    @ViewBuilder
    private func countRow(for action: CountAction) -> some View {
        let binding = Binding<String>(
            get: { countInputs[action.id] ?? "" },
            set: { countInputs[action.id] = $0 }
        )
        
        HStack(spacing: 10) {
            Image(systemName: action.icon)
                .foregroundColor(.white)
                .padding(8)
                .background(action.color.opacity(0.9))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 2) {
                Text(action.name).font(.subheadline.bold())
                Text("\(action.pointsPerUnit) WP per \(action.unit)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            TextField(action.unit, text: binding)
                #if os(iOS)
                .keyboardType(.numberPad)
                #endif
                .textFieldStyle(.roundedBorder)
                .frame(width: 80)
            Button("Add") {
                let n = Int(binding.wrappedValue) ?? 0
                if n > 0 {
                    let points = n * action.pointsPerUnit
                    earnWillpower(points, reason: "\(n) \(action.unit) • \(action.name)")
                    countInputs[action.id] = ""
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(action.color)
        }
        .padding(10)
        .background(Material.regular)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func earnWillpower(_ amount: Int, reason: String) {
        guard amount > 0 else { return }
        user.willpower += amount
        logs.insert(.init(date: .now, amount: amount, reason: reason), at: 0)
        logs = Array(logs.prefix(12))
        lastRewardText = "+\(amount) Willpower – \(reason)"
        withAnimation { showRewardBanner = true }
        SensoryFeedbackManager.shared.trigger(for: .taskCompleted)
    }
    
    // MARK: - Health Sync (optional)
    private var healthSyncSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Integrations").font(.title3.bold()).padding(.horizontal)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "heart.fill").foregroundColor(.red)
                    Text("Health Sync")
                        .font(.headline)
                    Spacer()
                    if healthAuthorized {
                        ChipView(text: "Connected")
                    }
                }
                .padding(.bottom, 2)
                
                HStack(spacing: 8) {
                    Button(healthAuthorized ? "Recheck" : "Connect") {
                        hkManager.requestAuthorization { ok in
                            healthAuthorized = ok
                        }
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Claim Steps") {
                        hkManager.fetchStepCount { steps in
                            let stepsInt = Int(steps ?? 0)
                            // 1 WP per 1000 steps
                            let wp = max(0, stepsInt / 1000)
                            if wp > 0 && !didClaimStepsToday {
                                earnWillpower(wp, reason: "Health: Steps \(stepsInt)")
                                didClaimStepsToday = true
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    .disabled(!healthAuthorized || didClaimStepsToday)
                    
                    Button("Claim Workout") {
                        hkManager.fetchWorkoutDuration { minutes in
                            let mins = Int(minutes ?? 0)
                            if mins > 0 && !didClaimWorkoutsToday {
                                earnWillpower(mins, reason: "Health: Workout \(mins)m")
                                didClaimWorkoutsToday = true
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .disabled(!healthAuthorized || didClaimWorkoutsToday)
                    
                    Button("Claim Mindful") {
                        hkManager.fetchMindfulMinutes { minutes in
                            let mins = Int(minutes ?? 0)
                            if mins > 0 && !didClaimMindfulToday {
                                // 2 WP per mindful minute
                                earnWillpower(mins * 2, reason: "Health: Mindful \(mins)m")
                                didClaimMindfulToday = true
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.purple)
                    .disabled(!healthAuthorized || didClaimMindfulToday)
                }
                .font(.caption)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                
                Text("Claim once per session to avoid double counting. Mapping: 1k steps = 1 WP, 1 workout min = 1 WP, 1 mindful min = 2 WP.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Material.regular)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal)
        }
    }
    
    // MARK: - Session Log
    private var sessionLogSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Session Log").font(.title3.bold()).padding(.horizontal)
            VStack(spacing: 8) {
                ForEach(logs) { log in
                    HStack {
                        Text(log.date, style: .time).font(.caption2).foregroundColor(.secondary)
                        Text(log.reason).font(.caption)
                        Spacer()
                        Text("+\(log.amount)")
                            .font(.caption.bold().monospacedDigit())
                            .foregroundColor(.green)
                    }
                    .padding(8)
                    .background(Material.thin)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Helpers
    private var finishedAllStatuesCard: some View {
        VStack(spacing: 10) {
            Text("All statues complete!")
                .font(.headline)
            Text("Your legend echoes through the sanctuary.")
                .font(.caption)
                .foregroundColor(.secondary)
            Button {
                // Convert willpower overflow to gold at 1:1 for fun
                let converted = user.willpower
                if converted > 0 {
                    user.willpower = 0
                    user.gold += converted
                    lastRewardText = "Converted \(converted) WP to Gold"
                    showRewardBanner = true
                }
            } label: {
                Label("Convert Willpower to Gold", systemImage: "creditcard")
            }
            .buttonStyle(JuicyButtonStyle())
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Material.regular)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }
}

// MARK: - Local types
private struct CountAction: Identifiable {
    let id: String
    let name: String
    let unit: String
    let pointsPerUnit: Int
    let color: Color
    let icon: String
}
private struct TapAction: Identifiable {
    let id: String
    let name: String
    let points: Int
    let color: Color
    let icon: String
}
private struct WillpowerLog: Identifiable {
    let id = UUID()
    let date: Date
    let amount: Int
    let reason: String
}

private struct ChipView: View {
    var text: String
    var body: some View {
        Text(text)
            .font(.caption.bold())
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(Color.white.opacity(0.12))
            .clipShape(Capsule())
    }
}

// MARK: - Challenge Row View
struct ChallengeRowView: View {
    let challenge: WeeklyChallenge
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(challenge.title).font(.headline).foregroundColor(challenge.isCompleted ? .green : .primary)
            Text(challenge.challengeDescription).font(.caption).foregroundColor(.secondary)
            ProgressView(value: Double(challenge.progress), total: Double(challenge.goal)).progressViewStyle(LinearProgressViewStyle()).tint(challenge.isCompleted ? .green : .accentColor)
        }
        .padding(.vertical, 5)
    }
}

// MARK: - Journal View
struct JournalView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var users: [User] = []
    private var user: User? { users.first }
    
    @Binding var didLevelUp: Bool
    @Binding var didEvolve: Bool
    
    @State private var entryText: String = ""
    @State private var moodRating: Int = 3
    @State private var journalSavedTrigger = false
    
    let prompts = [
        "What is one thing you're proud of today, no matter how small?",
        "What is a challenge you faced, and how did you handle it?",
        "Describe a moment today that made you smile."
    ]
    @State private var currentPrompt: String
    
    init(didLevelUp: Binding<Bool>, didEvolve: Binding<Bool>) {
        self._didLevelUp = didLevelUp
        self._didEvolve = didEvolve
        _currentPrompt = State(initialValue: prompts.randomElement() ?? "How are you feeling today?")
    }
    
    var body: some View {
        VStack(spacing: 15) {
            VStack {
                Text("Today's Prompt").font(.headline).foregroundColor(.secondary)
                Text(currentPrompt).padding().frame(maxWidth: .infinity).background(Color.secondary.opacity(0.1)).cornerRadius(10)
            }
            TextEditor(text: $entryText).padding(5).overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.3), lineWidth: 1))
            HStack {
                Text("My mood:")
                Picker("Mood", selection: $moodRating) {
                    ForEach(1...5, id: \.self) { Text("😀".prefix($0)).tag($0) }
                }.pickerStyle(.segmented)
            }
            Button("Save Entry") {
                saveJournalEntry()
                dismiss()
            }
            .buttonStyle(JuicyButtonStyle())
            .disabled(entryText.isEmpty)
        }
        .padding()
        .navigationTitle(Date().formatted(date: .abbreviated, time: .omitted))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .sensoryFeedback(.selection, trigger: journalSavedTrigger)
    }
    
    private func saveJournalEntry() {
        guard let user = user else { return }
        
        let newEntry = JournalEntry(date: .now, moodRating: moodRating, entryText: entryText, promptUsed: currentPrompt)
        modelContext.insert(newEntry)
        
        let result = GameLogicManager.shared.awardXPForJournaling(to: user)
        if result.didLevelUp {
            didLevelUp = true
            SensoryFeedbackManager.shared.trigger(for: .levelUp)
        }
        if result.didEvolve {
            didEvolve = true
            SensoryFeedbackManager.shared.trigger(for: .chimeraEvolved)
        }
        
        SensoryFeedbackManager.shared.trigger(for: .journalSaved)
        journalSavedTrigger.toggle()
    }
}
