import Foundation

public enum TemperingCost {
    public static let shardPerReroll = 3
}

public final class TemperingForge {
    public init() {}
    public func reroll(item: inout GearItem, affixIndex: Int) -> Bool {
        guard item.affixes.indices.contains(affixIndex),
              item.affixes[affixIndex].tempered == false else { return false }
        let key = item.affixes[affixIndex].affix
        item.affixes[affixIndex].value = AffixPool.roll(for: key, rarity: item.rarity)
        item.affixes[affixIndex].tempered = true
        return true
    }
}
