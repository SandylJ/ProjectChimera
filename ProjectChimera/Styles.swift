import SwiftUI

/// A custom button style that provides a "juicy" visual and interactive feel.
struct JuicyButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.accentColor)
            .foregroundColor(.white)
            .clipShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}

// Shared reward row for displaying loot in popups and lists
struct RewardRowView: View {
    let reward: LootReward
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundColor(color)
            Text(label)
            Spacer()
        }
        .font(.body)
    }
    private var label: String {
        switch reward {
        case .currency(let amount): return "\(amount) Gold"
        case .item(let id, let quantity):
            if let item = ItemDatabase.shared.getItem(id: id) { return "\(item.name) (x\(quantity))" }
            return "Item (x\(quantity))"
        case .experienceBurst(let skill, let amount): return "+\(amount) \(skill.rawValue.capitalized) XP"
        case .runes(let amount): return "\(amount) Runes"
        case .echoes(let amount): return String(format: "%.0f Echoes", amount)
        }
    }
    private var icon: String {
        switch reward {
        case .currency: return "dollarsign.circle.fill"
        case .item: return "shippingbox.fill"
        case .experienceBurst: return "sparkles"
        case .runes: return "circle.hexagonpath.fill"
        case .echoes: return "speaker.wave.2.circle.fill"
        }
    }
    private var color: Color {
        switch reward {
        case .currency: return .yellow
        case .item: return .blue
        case .experienceBurst: return .purple
        case .runes: return .cyan
        case .echoes: return .gray
        }
    }
}
