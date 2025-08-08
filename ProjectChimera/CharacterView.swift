import SwiftUI
import SwiftData
#if canImport(Vortex)
import Vortex
#endif

struct TaskItem: Identifiable, Equatable {
    var id = UUID(); let name: String; let xp: Int; let category: SkillCategory; var isCompleted: Bool = false
}

struct CharacterView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var users: [User]
    private var user: User? { users.first }

    @State private var didLevelUp = false; @State private var didEvolve = false
    @State private var dailyTasks: [TaskItem] = []
    @State private var showGoldPop: Bool = false; @State private var lastGoldAmount: Int = 0
    @State private var showNewSeedBanner: Bool = false; @State private var lastEarnedSeedName: String = ""
    @State private var showSkillLevelUpBanner = false; @State private var leveledSkillName = ""
    @State private var newSkillLevel = 1
    @State private var completedStrengthTasks: [String: Int] = [:]; @State private var completedMindTasks: [String: Int] = [:]
    @State private var completedJoyTasks: [String: Int] = [:]; @State private var completedVitalityTasks: [String: Int] = [:]
    @State private var completedAwarenessTasks: [String: Int] = [:]; @State private var completedFlowTasks: [String: Int] = [:]

    var body: some View {
        NavigationView {
            ZStack {
                if let user = user {
                    VStack(spacing: 0) {
                        CharacterSkillsHeader(user: user, didEvolve: $didEvolve, completedTasks: [
                            .strength: completedStrengthTasks, .mind: completedMindTasks, .joy: completedJoyTasks,
                            .vitality: completedVitalityTasks, .awareness: completedAwarenessTasks, .flow: completedFlowTasks
                        ])
                        ActiveBuffsView(user: user)
                        DailyHabitsView(
                            tasks: $dailyTasks,
                            onComplete: { task in handleTaskCompletion(task: task, for: user) },
                            onNewDay: { beginNewDay(for: user) }
                        )
                        NavigationLink(destination: TaskListView(user: user, didLevelUp: $didLevelUp, didEvolve: $didEvolve)) {
                            Label("View My Projects & Goals", systemImage: "list.bullet.clipboard.fill")
                                .font(.headline).frame(maxWidth: .infinity).padding()
                                .background(Color.accentColor.opacity(0.8)).foregroundColor(.white)
                                .cornerRadius(10).padding()
                        }
                        NavigationLink(destination: EquipmentView(user: user)) {
                            Label("View Equipment", systemImage: "shield.fill")
                                .font(.headline).frame(maxWidth: .infinity).padding()
                                .background(Color.accentColor.opacity(0.8)).foregroundColor(.white)
                                .cornerRadius(10).padding()
                        }
                    }
                    .navigationTitle("Character")
                    #if os(iOS)
                    .navigationBarHidden(true)
                    #endif
                    .onAppear {
                        if dailyTasks.isEmpty { dailyTasks = Self.generateNewDailyTasks() }
                        ChallengeManager.shared.generateWeeklyChallenges(for: user, context: modelContext)
                        // --- NEW: Unlock spells on appear ---
                        SpellbookManager.shared.unlockNewSpells(for: user)
                    }
                } else {
                    ProgressView().navigationTitle("Character")
                }
                LevelUpOverlay(didLevelUp: $didLevelUp)
                bannerOverlay
            }
        }
    }
    

    
    @ViewBuilder
    private var bannerOverlay: some View {
        VStack {
            if showSkillLevelUpBanner {
                Text("🎉 Skill Level Up! \(leveledSkillName) is now Level \(newSkillLevel)! 🎉")
                    .padding().background(.purple).foregroundColor(.white).cornerRadius(10)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 3) { showSkillLevelUpBanner = false } }
            }
            if showGoldPop {
                Text("+\(lastGoldAmount) Gold!")
                    .padding().background(Color.yellow.opacity(0.9)).cornerRadius(10)
                    .transition(.scale.combined(with: .opacity))
                    .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 2) { showGoldPop = false } }
            }
            if showNewSeedBanner {
                Text("🌱 You found a \(lastEarnedSeedName)! Check your Sanctuary.")
                    .padding().background(.blue).foregroundColor(.white).cornerRadius(10)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 3) { showNewSeedBanner = false } }
            }
            Spacer()
        }
        .animation(.spring(), value: showSkillLevelUpBanner)
        .animation(.spring(), value: showGoldPop)
        .animation(.spring(), value: showNewSeedBanner)
    }
    
    private func handleTaskCompletion(task: TaskItem, for user: User) {
        if let index = dailyTasks.firstIndex(where: { $0.id == task.id }) {
            dailyTasks[index].isCompleted = true
            trackCompletedDailyTask(task)
            let result = GameLogicManager.shared.awardXP(for: task, to: user)
            if result.didLevelUp { didLevelUp = true }
            if result.didEvolve { didEvolve = true }
            if result.didSkillLevelUp {
                self.leveledSkillName = result.skillName; self.newSkillLevel = result.newLevel
                self.showSkillLevelUpBanner = true; SensoryFeedbackManager.shared.trigger(for: .skillLevelUp)
            }
            if Double.random(in: 0...1) < 0.2 {
                var goldAmount = Int.random(in: 10...50)
                // Apply double gold buff if active
                if user.activeBuffs.keys.contains(.doubleGold) { goldAmount *= 2 }
                user.gold += goldAmount
                lastGoldAmount = goldAmount; showGoldPop = true
            }
            if Double.random(in: 0...1) < 0.1 {
                if let randomSeed = ItemDatabase.shared.getAllPlantables().randomElement() {
                    if let invItem = user.inventory?.first(where: { $0.itemID == randomSeed.id }) { invItem.quantity += 1 }
                    else { user.inventory?.append(InventoryItem(itemID: randomSeed.id, quantity: 1, owner: user)) }
                    lastEarnedSeedName = randomSeed.name; showNewSeedBanner = true
                }
            }
        }
    }
    
    private func trackCompletedDailyTask(_ task: TaskItem) {
        switch task.category {
        case .strength: completedStrengthTasks[task.name, default: 0] += 1
        case .mind: completedMindTasks[task.name, default: 0] += 1
        case .joy: completedJoyTasks[task.name, default: 0] += 1
        case .vitality: completedVitalityTasks[task.name, default: 0] += 1
        case .awareness: completedAwarenessTasks[task.name, default: 0] += 1
        case .flow: completedFlowTasks[task.name, default: 0] += 1
        default: break
        }
    }
    
    private func beginNewDay(for user: User) {
        user.gold += 100
        dailyTasks = Self.generateNewDailyTasks()
    }

    static let strengthTasks: [TaskItem] = [TaskItem(name: "Run 3 miles", xp: 50, category: .strength), TaskItem(name: "30 min workout", xp: 40, category: .strength)]
    static let mindTasks: [TaskItem] = [TaskItem(name: "Meditate 10 mins", xp: 20, category: .mind), TaskItem(name: "Read 20 pages", xp: 15, category: .mind)]
    static let joyTasks: [TaskItem] = [TaskItem(name: "Talk to a friend", xp: 15, category: .joy), TaskItem(name: "Listen to music", xp: 10, category: .joy)]
    static let vitalityTasks: [TaskItem] = [TaskItem(name: "Stretch for 15 mins", xp: 20, category: .vitality), TaskItem(name: "Get 8 hours sleep", xp: 40, category: .vitality)]
    static let awarenessTasks: [TaskItem] = [TaskItem(name: "Journal", xp: 25, category: .awareness), TaskItem(name: "Mindful breathing", xp: 15, category: .awareness)]
    static let flowTasks: [TaskItem] = [TaskItem(name: "Deep work session", xp: 50, category: .flow), TaskItem(name: "Work on hobby", xp: 30, category: .flow)]
    
    static func generateNewDailyTasks() -> [TaskItem] {
        var newTasks: [TaskItem] = []
        if let task = strengthTasks.randomElement() { newTasks.append(task) }
        if let task = mindTasks.randomElement() { newTasks.append(task) }
        if let task = joyTasks.randomElement() { newTasks.append(task) }
        if let task = vitalityTasks.randomElement() { newTasks.append(task) }
        if let task = awarenessTasks.randomElement() { newTasks.append(task) }
        if let task = flowTasks.randomElement() { newTasks.append(task) }
        return newTasks.shuffled()
    }
}

struct CharacterSkillsHeader: View {
    let user: User; @Binding var didEvolve: Bool; let completedTasks: [SkillCategory: [String: Int]]
    var body: some View {
        VStack {
            HStack(alignment: .center, spacing: 16) {
                VStack(spacing: 20) {
                    skillNavLink(skill: .strength, icon: "figure.strengthtraining.traditional", xp: user.xpStrength, level: user.levelStrength)
                    skillNavLink(skill: .mind, icon: "brain.head.profile", xp: user.xpMind, level: user.levelMind)
                    skillNavLink(skill: .joy, icon: "face.smiling", xp: user.xpJoy, level: user.levelJoy)
                }
                VStack {
                    Text(user.chimera?.name ?? "Chimera").font(.largeTitle).bold()
                    CharacterHeaderView(user: user, didEvolve: $didEvolve)
                    Text("Level \(user.level)").font(.headline).bold()
                }.frame(maxWidth: .infinity)
                VStack(spacing: 20) {
                    skillNavLink(skill: .vitality, icon: "bolt.heart", xp: user.xpVitality, level: user.levelVitality)
                    skillNavLink(skill: .awareness, icon: "eye", xp: user.xpAwareness, level: user.levelAwareness)
                    skillNavLink(skill: .flow, icon: "wind", xp: user.xpFlow, level: user.levelFlow)
                }
            }.padding()
        }.background(Color.secondary.opacity(0.1))
    }
    private func skillNavLink(skill: SkillCategory, icon: String, xp: Int, level: Int) -> some View {
        NavigationLink(destination: SkillDetailView(skillName: skill.rawValue.capitalized, progress: Double(xp) / 100.0, level: level, completedTasks: completedTasks[skill] ?? [:])) {
            boxedSkillIcon(name: icon, progress: Double(xp) / 100.0)
        }
    }
    @ViewBuilder private func boxedSkillIcon(name: String, progress: Double) -> some View {
        ZStack {
            Circle().stroke(lineWidth: 5.0).opacity(0.3).foregroundColor(Color.purple)
            Circle().trim(from: 0.0, to: CGFloat(min(progress, 1.0)))
                .stroke(style: StrokeStyle(lineWidth: 5.0, lineCap: .round, lineJoin: .round))
                .foregroundColor(Color.purple).rotationEffect(Angle(degrees: 270.0))
            Image(systemName: name).font(.title2).foregroundColor(.purple)
        }.frame(width: 50, height: 50)
    }
}

struct SkillDetailView: View {
    let skillName: String; let progress: Double; let level: Int; let completedTasks: [String: Int]
    var body: some View {
        VStack(spacing: 20) {
            Text("\(skillName) - Level \(level)").font(.largeTitle).bold()
            ProgressView(value: progress).progressViewStyle(LinearProgressViewStyle(tint: .purple)).scaleEffect(x: 1, y: 2, anchor: .center)
            Text("\(Int(progress * 100)) / 100 XP")
            List {
                Section(header: Text("Completed Tasks")) {
                    if completedTasks.isEmpty { Text("No tasks completed for this skill yet.") }
                    else { ForEach(completedTasks.sorted(by: { $0.value > $1.value }), id: \.key) { key, value in HStack { Text(key); Spacer(); Text("\(value) time(s)") } } }
                }
            }
        }.padding().navigationTitle(skillName)
    }
}

struct DailyHabitsView: View {
    @Binding var tasks: [TaskItem]; var onComplete: (TaskItem) -> Void; var onNewDay: () -> Void
    var body: some View {
        VStack {
            if tasks.allSatisfy({ $0.isCompleted }) {
                VStack(spacing: 20) {
                    Spacer()
                    Text("All Habits Honored for Today!").font(.title2).bold().multilineTextAlignment(.center)
                    Text("Your consistency has been rewarded.").foregroundColor(.secondary)
                    Button(action: onNewDay) { Text("Begin a New Day").padding().background(Color.green).foregroundColor(.white).cornerRadius(10) }
                    Spacer()
                }.padding()
            } else {
                ScrollView { LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 16) { ForEach(tasks.filter { !$0.isCompleted }) { task in taskBubble(task: task) } }.padding() }
            }
        }.frame(maxHeight: .infinity)
    }
    private func taskBubble(task: TaskItem) -> some View {
        Button(action: { onComplete(task) }) {
            VStack {
                Text(task.name).font(.headline).fixedSize(horizontal: false, vertical: true)
                Spacer()
                Text("+\(task.xp) XP").font(.caption).foregroundColor(.secondary)
            }.padding().frame(minHeight: 100).background(Color.yellow.opacity(0.2)).cornerRadius(15)
        }.buttonStyle(PlainButtonStyle())
    }
}

struct CharacterHeaderView: View {
    var user: User; @Binding var didEvolve: Bool
    var body: some View {
        VStack {
            ZStack {
                if let chimera = user.chimera { ChimeraView(chimera: chimera).padding(.vertical) }
                #if canImport(Vortex)
                if didEvolve {
                    VortexView(.magic) { Circle().fill(.white).frame(width: 16).blendMode(.plusLighter).tag("circle") }
                        .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 2) { didEvolve = false } }
                }
                #endif
            }
        }
    }
}
