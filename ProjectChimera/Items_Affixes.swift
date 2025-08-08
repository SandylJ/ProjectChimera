import Foundation

public enum GearSlot: String, Codable, CaseIterable { case ring }

public struct AffixRoll: Codable, Hashable {
    public let affix: String
    public var value: Double
    public var tempered: Bool
}

public struct GearItem: Identifiable, Codable, Hashable {
    public let id: UUID = .init()
    public var slot: GearSlot
    public var rarity: Rarity
    public var name: String
    public var affixes: [AffixRoll]

    enum CodingKeys: String, CodingKey {
        case slot, rarity, name, affixes
    }
}

public enum AffixPool {
    static let ranges: [String: ClosedRange<Double>] = [
        "energyRegen": 0.02...0.10,
        "taskGold": 0.05...0.20,
        "idleYield": 0.05...0.20,
        "craftSpeed": 0.05...0.20,
        "critChance": 0.01...0.05
    ]
    static func roll(for key: String, rarity: Rarity) -> Double {
        let base = ranges[key] ?? 0.01...0.01
        let width = base.upperBound - base.lowerBound
        let rarityBoost: Double = {
            switch rarity {
            case .common: return 0.0
            case .rare: return 0.2
            case .epic: return 0.5
            case .legendary: return 0.8
            }
        }()
        let r = Double.random(in: 0...1)
        return (base.lowerBound + r * width) * (1.0 + rarityBoost)
    }
}

public enum RingFactory {
    public static func newRing(rarity: Rarity) -> GearItem {
        let pool = ["energyRegen", "taskGold", "idleYield", "craftSpeed", "critChance"]
        let affixCount: Int = {
            switch rarity {
            case .common: return 2
            case .rare: return 3
            case .epic, .legendary: return 4
            }
        }()
        let rolls = Array(pool.shuffled().prefix(affixCount)).map {
            AffixRoll(affix: $0, value: AffixPool.roll(for: $0, rarity: rarity), tempered: false)
        }
        return .init(slot: .ring, rarity: rarity, name: "\(rarity.rawValue.capitalized) Ring", affixes: rolls)
    }
}
