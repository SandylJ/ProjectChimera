import Foundation
import Combine

public protocol ChallengeGameHooks: AnyObject {
    func grant(_ reward: RewardBundle)
    var currentSteps: Int { get }
}

public final class DailyChallengeManager: ObservableObject {
    @Published public private(set) var todays: [DailyChallenge] = []
    @Published public private(set) var streak: Int = 0
    @Published public var lastRolled: Date?

    private var cancellables = Set<AnyCancellable>()
    private weak var hooks: ChallengeGameHooks?

    public init(hooks: ChallengeGameHooks? = nil) {
        self.hooks = hooks
        if todays.isEmpty { rollNewSet() }
    }

    public func attach(hooks: ChallengeGameHooks) {
        self.hooks = hooks
    }

    public func rollNewSet(date: Date = .now) {
        lastRolled = date
        var pool: [DailyChallenge] = []
        pool.append(.init(kind: .tasksCompleted, target: 5, reward: .init(gold: 50)))
        pool.append(.init(kind: .steps, target: 4000, reward: .init(items: ["streak_token": 1])))
        pool.append(.init(kind: .crafting, target: 10, reward: .init(gold: 75)))
        todays = Array(pool.prefix(3))
    }

    public func applyProgress(kind: ChallengeKind, delta: Int = 1) {
        for idx in todays.indices {
            if todays[idx].kind == kind && !todays[idx].isDone {
                todays[idx].progress = min(todays[idx].progress + delta, todays[idx].target)
            }
        }
    }

    public func redeemCompleted() {
        guard let hooks else { return }
        var redeemed = false
        for c in todays where c.isDone {
            hooks.grant(c.reward)
            redeemed = true
        }
        if redeemed { streak += 1 }
    }
}
