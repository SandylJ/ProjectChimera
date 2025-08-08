import Foundation
import SwiftData

final class AchievementManager {
    static let shared = AchievementManager()
    private init() {}

    /// Records a new achievement for the given user.
    func unlock(title: String, description: String, for user: User, context: ModelContext? = nil) {
        let achievement = Achievement(title: title, achievementDescription: description, dateEarned: .now, owner: user)
        if user.achievements == nil { user.achievements = [] }
        user.achievements?.append(achievement)
        if let context = context { context.insert(achievement) }
    }
}
