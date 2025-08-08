import Foundation
import Combine

public protocol PrestigeGameState {
    var totalPowerEarned: Int { get set }
    var gold: Int { get set }
    var inventory: [String: Int] { get set }
    mutating func softResetPreservingMeta()
}

public final class AscensionManager: ObservableObject {
    @Published public private(set) var prestigeCurrency: Int = 0
    @Published public private(set) var ownedPerkIDs: Set<String> = []
    @Published public var availablePerks: [PrestigePerk] = PrestigeCatalog.perks

    public init() {}

    public func canAscend(currentTotalPower: Int) -> Bool {
        currentTotalPower >= 1_000
    }

    public func projectedGain(for totalPower: Int) -> Int {
        max(1, Int(sqrt(Double(max(totalPower, 0))) / 10.0))
    }

    public func ascend<S: PrestigeGameState>(state: inout S) {
        let gain = projectedGain(for: state.totalPowerEarned)
        prestigeCurrency += gain
        state.softResetPreservingMeta()
    }

    public func purchase(perk: PrestigePerk) -> Bool {
        guard !ownedPerkIDs.contains(perk.id), prestigeCurrency >= perk.cost else { return false }
        prestigeCurrency -= perk.cost
        ownedPerkIDs.insert(perk.id)
        return true
    }

    public func multiplier(for key: String) -> Double {
        availablePerks
            .filter { ownedPerkIDs.contains($0.id) }
            .reduce(1.0) { acc, p in acc * (p.multipliers[key] ?? 1.0) }
    }
}
