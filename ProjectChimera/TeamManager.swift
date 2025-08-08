import Foundation
import SwiftData

/// Provides basic team management such as creation and point tracking.
final class TeamManager: ObservableObject {
    static let shared = TeamManager()
    private init() {}

    func createTeam(name: String, for user: User, context: ModelContext) {
        guard user.team == nil else { return }
        let team = Team(name: name, owner: user)
        context.insert(team)
        user.team = team
    }

    func addPoints(_ points: Int, to user: User) {
        user.teamPoints += points
    }
}
