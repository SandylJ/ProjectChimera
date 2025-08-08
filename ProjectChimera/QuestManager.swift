import Foundation
import SwiftData

/// Handles creation and progression of quests for a user.
final class QuestManager {
    static let shared = QuestManager()
    private init() {}

    func initializeQuests(for user: User, context: ModelContext) {
        guard user.quests?.isEmpty ?? true else { return }
        for template in ItemDatabase.shared.masterQuestList {
            let newQuest = Quest(
                id: template.id,
                title: template.title,
                description: template.questDescription,
                type: template.type,
                rewards: template.rewards,
                owner: user
            )
            context.insert(newQuest)
            user.quests?.append(newQuest)
        }
    }

    func updateQuestProgress(forCompletedTask task: TaskItem, on user: User) {
        guard let activeQuests = user.quests?.filter({ $0.status == .active }) else { return }
        for quest in activeQuests {
            switch quest.type {
            case .milestone(let category, let count):
                if category == task.category {
                    quest.progress += 1
                    if quest.progress >= count { quest.status = .completed }
                }
            case .streak(let category, let days):
                if category == task.category {
                    quest.progress += 1
                    if quest.progress >= days { quest.status = .completed }
                }
            case .exploration(let categories):
                if categories.contains(task.category) {
                    quest.progress += 1
                    if quest.progress >= categories.count { quest.status = .completed }
                }
            }
        }
    }

    func claimQuestReward(for quest: Quest, on user: User, context: ModelContext) {
        for reward in quest.rewards {
            IdleGameManager.shared.grantLoot(reward, to: user, context: context)
        }
        context.delete(quest)
    }
}
