import Foundation

public struct PrestigePerk: Identifiable, Codable, Hashable {
    public let id: String
    public let name: String
    public let desc: String
    public let cost: Int
    public let multipliers: [String: Double] // e.g., ["idleYield": 1.10]

    public init(id: String, name: String, desc: String, cost: Int, multipliers: [String: Double]) {
        self.id = id
        self.name = name
        self.desc = desc
        self.cost = cost
        self.multipliers = multipliers
    }
}

public enum PrestigeCatalog {
    public static let perks: [PrestigePerk] = [
        .init(id: "idle_1", name: "Early Riser", desc: "+10% idle yield", cost: 3, multipliers: ["idleYield": 1.10]),
        .init(id: "tasks_1", name: "Taskmaster", desc: "+10% task gold", cost: 3, multipliers: ["taskGold": 1.10]),
        .init(id: "craft_1", name: "Greased Gears", desc: "+10% crafting speed", cost: 3, multipliers: ["craftSpeed": 1.10]),
    ]
}
