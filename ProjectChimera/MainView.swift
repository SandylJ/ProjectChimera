import SwiftUI
import SwiftData

struct MainView: View {
    @EnvironmentObject var onboardingManager: OnboardingManager

    var body: some View {
        Group {
            if onboardingManager.hasCompletedOnboarding {
                AppTabView()
            } else {
                OnboardingView()
            }
        }
        .onAppear {
            // If onboarding is completed but no user exists, create one
            if onboardingManager.hasCompletedOnboarding {
                // This will be handled in AppTabView.onAppear
            } else {
                // Force complete onboarding if there are issues
                print("Onboarding not completed, forcing completion...")
                onboardingManager.completeOnboarding()
            }
        }
    }
}

struct AppTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var users: [User]
    private var user: User? { users.first }
    
    var body: some View {
        TabView {
            CharacterView()
                .tabItem {
                    Label("Character", systemImage: "person.fill")
                }

            // Lair: Character customization + inventory dashboard
            NavigationView {
                LairView()
            }
            .tabItem {
                Label("Lair", systemImage: "pawprint.circle.fill")
            }
            
            // Promote Sanctuary to second tab for prominence
            SanctuaryView()
                .tabItem {
                    Label("Sanctuary", systemImage: "tree.fill")
                }
            
            if let user = user {
                NavigationView {
                    SpellbookView(user: user)
                }
                .tabItem {
                    Label("Spellbook", systemImage: "book.closed.fill")
                }
            } else {
                ProgressView().tabItem { Label("Spellbook", systemImage: "book.closed.fill") }
            }
            
            if let user = user {
                NavigationView {
                    CraftingView(user: user)
                }
                .tabItem {
                    Label("Crafting", systemImage: "hammer.fill")
                }
            } else {
                ProgressView().tabItem { Label("Crafting", systemImage: "hammer.fill") }
            }
            
            if let user = user {
                NavigationView {
                    QuestsView(user: user)
                }
                .tabItem {
                    Label("Quests", systemImage: "scroll.fill")
                }
            } else {
                ProgressView().tabItem { Label("Quests", systemImage: "scroll.fill") }
            }
            
            // --- NEW: Shop Tab ---
            if let user = user {
                NavigationView {
                    ShopView(user: user)
                }
                .tabItem {
                    Label("Shop", systemImage: "cart.fill")
                }
            } else {
                ProgressView().tabItem { Label("Shop", systemImage: "cart.fill") }
            }
            
            // --- NEW: Ascension Tab ---
            NavigationView {
                AscensionView(ascension: AscensionManager(), state: .constant(GameState()))
            }
            .tabItem {
                Label("Ascend", systemImage: "arrow.uturn.up")
            }
            
            // --- NEW: Challenges Tab ---
            NavigationView {
                ChallengesView(manager: DailyChallengeManager())
            }
            .tabItem {
                Label("Challenges", systemImage: "list.bullet.rectangle")
            }
        }
        .onAppear {
            print("AppTabView appeared, users count: \(users.count)")
            // Ensure a user exists
            if users.isEmpty {
                print("No users found, creating default user...")
                createDefaultUser()
            } else {
                print("Found \(users.count) users")
                // Initialize systems for existing user on first appearance
                if let user = user {
                    IdleGameManager.shared.initializeAltar(for: user, context: modelContext)
                    ObsidianGymnasiumManager.shared.initializeStatues(for: user, context: modelContext)
                    QuestManager.shared.initializeQuests(for: user, context: modelContext)
                }
            }
        }
    }
    

    
    private func createDefaultUser() {
        print("Creating default user...")
        let newUser = User(username: "PlayerOne")
        modelContext.insert(newUser)
        
        // Initialize guild for the user
        GuildManager.shared.initializeGuild(for: newUser, context: modelContext)
        
        // Generate initial bounties
        GuildManager.shared.generateDailyBounties(for: newUser, context: modelContext)
        
        // Initialize other managers
        ChallengeManager.shared.generateWeeklyChallenges(for: newUser, context: modelContext)
        SpellbookManager.shared.unlockNewSpells(for: newUser)
        IdleGameManager.shared.initializeAltar(for: newUser, context: modelContext)
        ObsidianGymnasiumManager.shared.initializeStatues(for: newUser, context: modelContext)
        QuestManager.shared.initializeQuests(for: newUser, context: modelContext)

        do {
            try modelContext.save()
            print("Default user created successfully")
        } catch {
            print("Failed to save default user: \(error)")
        }
    }
}

#Preview {
    MainView()
        .modelContainer(for: [User.self, Task.self], inMemory: true)
}
