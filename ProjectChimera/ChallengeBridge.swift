import Foundation

final class ChallengeBridge: ChallengeGameHooks {
    private let getState: () -> GameState
    private let setState: (GameState) -> Void

    init(get: @escaping () -> GameState, set: @escaping (GameState) -> Void) {
        self.getState = get
        self.setState = set
    }

    // Wire HealthKit later if desired
    var currentSteps: Int { 0 }

    func grant(_ reward: RewardBundle) {
        var s = getState()
        if reward.gold != 0 { s.addGold(reward.gold) }
        for (id, qty) in reward.items { s.addItem(id: id, quantity: qty) }
        setState(s)
    }
}
