import SwiftUI
import SwiftData

@main
struct ProjectChimeraApp: App {
    // Each manager is initialized using its shared singleton instance. This
    // avoids access level issues from private initializers while still allowing
    // SwiftUI to manage their lifecycle via `@StateObject`.
    @StateObject private var gameManager = IdleGameManager.shared
    @StateObject private var healthKitManager = HealthKitManager()
    @StateObject private var onboardingManager = OnboardingManager.shared
    @StateObject private var equipmentManager = EquipmentManager.shared
    @StateObject private var sanctuaryManager = SanctuaryManager.shared
    @StateObject private var guildManager = GuildManager.shared
    @StateObject private var shopManager = ShopManager.shared
    @StateObject private var layoutSettings = LayoutSettings.shared

    var body: some Scene {
        WindowGroup {
            // CORRECTED: Inject each manager individually into the environment.
            // This is the standard SwiftUI pattern for providing dependencies to child views.
            ContentView()
                .environmentObject(gameManager)
                .environmentObject(healthKitManager)
                .environmentObject(onboardingManager)
                .environmentObject(equipmentManager)
                .environmentObject(sanctuaryManager)
                .environmentObject(guildManager)
                .environmentObject(shopManager)
                .environmentObject(layoutSettings)
                .modelContainer(for: [
                    User.self,
                    Task.self,
                    JournalEntry.self,
                    Guild.self,
                    Team.self,
                    GuildBounty.self,
                    Achievement.self,
                    Quest.self,
                    Statue.self,
                    Chimera.self,
                    SubTask.self,
                    InventoryItem.self,
                    PlantedHabitSeed.self,
                    PlantedCrop.self,
                    PlantedTree.self,
                    GuildMember.self,
                    ActiveExpedition.self,
                    AltarOfWhispers.self,
                    WeeklyChallenge.self,
                    ActiveHunt.self,
                    HatchableEgg.self
                ])
        }
    }
}
