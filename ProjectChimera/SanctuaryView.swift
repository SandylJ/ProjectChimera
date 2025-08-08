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
    
    @State private var repsToAdd: String = ""
    @State private var showRewardBanner = false
    @State private var lastRewardText = ""
    
    private var currentStatue: Statue? {
        user.statues?.first { $0.id == user.currentStatueID }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Obsidian Gymnasium")
                    .font(.largeTitle).bold()
                    .multilineTextAlignment(.center)
                
                Text("Your willpower shapes the stone.")
                    .font(.subheadline).foregroundColor(.secondary)
                
                Text("Willpower: \(user.willpower)")
                    .font(.title2.bold())
                    .foregroundColor(.purple)
                    .padding(.bottom)
                
                if let statue = currentStatue {
                    statueProgressView(statue: statue)
                } else {
                    Text("You have carved all the statues! Your strength is legendary.")
                        .font(.headline)
                        .padding()
                        .multilineTextAlignment(.center)
                }
            }
            .padding()
        }
        .navigationTitle("Gymnasium")
        .overlay(alignment: .top) {
            if showRewardBanner {
                Text(lastRewardText)
                    .padding()
                    .background(Color.green.opacity(0.9))
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            withAnimation { showRewardBanner = false }
                        }
                    }
            }
        }
    }
    
    @ViewBuilder
    private func statueProgressView(statue: Statue) -> some View {
        VStack(spacing: 15) {
            Text(statue.name)
                .font(.title.bold())
            
            Text(statue.statueDescription)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Image(systemName: "figure.stand")
                .resizable()
                .scaledToFit()
                .frame(height: 150)
                .foregroundColor(.gray.opacity(0.4))
                .overlay(
                    Image(systemName: "figure.stand")
                        .resizable()
                        .scaledToFit()
                        .foregroundColor(.black)
                        .clipShape(Rectangle().offset(y: 150 * (1 - CGFloat(statue.progress))))
                )
                .animation(.easeInOut, value: statue.progress)

            
            ProgressView(value: statue.progress)
                .progressViewStyle(LinearProgressViewStyle(tint: .purple))
                .scaleEffect(x: 1, y: 2.5, anchor: .center)

            Text("\(statue.currentWillpower) / \(statue.requiredWillpower) Willpower")
                .font(.caption)
            
            if statue.isComplete {
                Button("Claim Reward & Start Next") {
                    guard let context = user.modelContext else {
                        print("Error: Model context not available for completing statue.")
                        return
                    }
                    withAnimation {
                        ObsidianGymnasiumManager.shared.completeStatue(for: user, context: context)
                        lastRewardText = "Statue Complete! Reward: \(statue.reward.description)"
                        showRewardBanner = true
                    }
                }
                .buttonStyle(JuicyButtonStyle())
                .tint(.green)
            } else {
                willpowerInputView(statue: statue)
            }
        }
    }
    
    private func willpowerInputView(statue: Statue) -> some View {
        VStack {
            Text("Log workout reps to gain Willpower, or spend existing Willpower to chisel the statue.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.bottom, 5)
            
            HStack {
                TextField("Enter Reps (e.g., 10)", text: $repsToAdd)
                    #if os(iOS)
                    .keyboardType(.numberPad)
                    #endif
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Button("Add") {
                    if let reps = Int(repsToAdd) {
                        user.willpower += reps
                        repsToAdd = ""
                    }
                }
                .buttonStyle(.bordered)
            }
            
            Button("Chisel with \(user.willpower) Willpower") {
                withAnimation {
                    ObsidianGymnasiumManager.shared.chiselStatue(for: user, amount: user.willpower)
                }
            }
            .buttonStyle(JuicyButtonStyle())
            .disabled(user.willpower <= 0)
        }
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
