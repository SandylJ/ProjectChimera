
import SwiftUI
import SwiftData

struct ActiveBuffsView: View {
    @Bindable var user: User
    @State private var now = Date()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading) {
            if !user.activeBuffs.isEmpty {
                Text("Active Buffs")
                    .font(.headline)
                    .padding(.leading)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(user.activeBuffs.sorted(by: { $0.value < $1.value }), id: \.key) { effect, expiryDate in
                            BuffIconView(effect: effect, expiryDate: expiryDate, now: now)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .onReceive(timer) { newDate in
            self.now = newDate
            // Clean up expired buffs in real-time
            SpellbookManager.shared.cleanupExpiredBuffs(for: user)
        }
    }
}

struct BuffIconView: View {
    let effect: SpellEffect
    let expiryDate: Date
    let now: Date

    var body: some View {
        VStack {
            Image(systemName: effect.systemImage)
                .font(.title2)
                .foregroundColor(.white)
                .frame(width: 40, height: 40)
                .background(Color.purple.opacity(0.8))
                .cornerRadius(8)

            Text(effect.displayName)
                .font(.caption2)
                .foregroundColor(.white)

            Text(timeRemaining(until: expiryDate))
                .font(.caption2)
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(4)
        .background(Color.black.opacity(0.6))
        .cornerRadius(10)
    }

    private func timeRemaining(until date: Date) -> String {
        let remaining = date.timeIntervalSince(now)
        if remaining <= 0 { return "Expired" }
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: remaining) ?? "--"
    }
}
