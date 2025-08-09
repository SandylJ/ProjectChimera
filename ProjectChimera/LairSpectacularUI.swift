import SwiftUI

// MARK: - THEME

enum GameTheme {
    static let bgTop     = Color(red: 24/255,  green: 29/255,  blue: 54/255)
    static let bgBottom  = Color(red: 9/255,   green: 12/255,  blue: 28/255)
    static let panelFill = Color.white.opacity(0.06)
    static let panelStroke = Color.white.opacity(0.10)
    static let textPrimary = Color.white.opacity(0.95)
    static let textSecondary = Color.white.opacity(0.7)
    static let gold = Color.yellow
    static let gem  = Color.pink
    static let key  = Color.cyan
    static let okGradient = LinearGradient(colors: [.orange, .red], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let infoGradient = LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let bgGradient = LinearGradient(colors: [bgTop, bgBottom], startPoint: .top, endPoint: .bottom)
}

struct GlassCard<Content: View>: View {
    var corner: CGFloat = 22
    var content: () -> Content
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: corner)
                .fill(GameTheme.panelFill)
            RoundedRectangle(cornerRadius: corner)
                .stroke(GameTheme.panelStroke, lineWidth: 1)
        }
        .background(.black.opacity(0.001))
        .overlay(content())
    }
}

// MARK: - COMMON WIDGETS

struct CurrencyBadge: View {
    enum Kind { case coin, gem, key }
    var kind: Kind
    var amount: Int
    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle().fill(.ultraThinMaterial)
                    .overlay(Circle().stroke(GameTheme.panelStroke))
                    .frame(width: 28, height: 28)
                Image(systemName: icon).font(.system(size: 14, weight: .bold))
            }
            Text("\(amount)")
                .font(.system(.headline, design: .rounded)).monospacedDigit()
                .foregroundStyle(GameTheme.textPrimary)
        }
        .padding(.vertical, 6).padding(.horizontal, 10)
        .background(
            Capsule().fill(.white.opacity(0.08))
                .overlay(Capsule().stroke(.white.opacity(0.10)))
        )
    }
    var icon: String {
        switch kind {
        case .coin: return "creditcard.circle.fill"
        case .gem:  return "diamond.fill"
        case .key:  return "key.fill"
        }
    }
}

struct GameHUD: View {
    var coins: Int
    var gems: Int
    var keys: Int
    var body: some View {
        HStack(spacing: 10) {
            Button { } label: {
                Image(systemName: "gearshape.fill")
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(.white.opacity(0.08), in: Circle())
            }
            Spacer()
            CurrencyBadge(kind: .gem, amount: gems)
            CurrencyBadge(kind: .coin, amount: coins)
            CurrencyBadge(kind: .key, amount: keys)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

struct StatRow: View {
    let label: String
    let value: Int
    var body: some View {
        HStack {
            Text(label).font(.headline).foregroundStyle(GameTheme.textPrimary)
            Spacer()
            Text("\(value)")
                .font(.system(.headline, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(GameTheme.gold)
            Image(systemName: "chevron.right").foregroundStyle(.white.opacity(0.6))
        }
        .padding(12)
        .background(GameTheme.panelFill, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(GameTheme.panelStroke))
    }
}

struct ProgressBar: View {
    var progress: CGFloat // 0...1
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 8).fill(.white.opacity(0.08))
                RoundedRectangle(cornerRadius: 8)
                    .fill(LinearGradient(colors: [.green, .mint], startPoint: .leading, endPoint: .trailing))
                    .frame(width: geo.size.width * progress)
            }
        }
        .frame(height: 10)
    }
}

struct GlowButtonStyle: ButtonStyle {
    var gradient: LinearGradient = GameTheme.okGradient
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.headline, design: .rounded))
            .foregroundStyle(.white)
            .padding(.vertical, 14)
            .padding(.horizontal, 18)
            .background(gradient, in: RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(.white.opacity(configuration.isPressed ? 0.25 : 0.15), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.4), radius: 18, y: 10)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .overlay(AnimatedSheen().clipShape(RoundedRectangle(cornerRadius: 18)))
    }
}

struct AnimatedSheen: View {
    @State private var x: CGFloat = -1
    var body: some View {
        LinearGradient(stops: [
            .init(color: .white.opacity(0.0), location: 0.0),
            .init(color: .white.opacity(0.35), location: 0.5),
            .init(color: .white.opacity(0.0), location: 1.0)
        ], startPoint: .top, endPoint: .bottom)
        .frame(width: 40)
        .offset(x: x * 240)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: false)) {
                x = 1.2
            }
        }
        .blendMode(.screen)
        .opacity(0.5)
    }
}

struct Chip: View {
    var text: String
    var body: some View {
        Text(text)
            .font(.system(.footnote, design: .rounded).weight(.bold))
            .foregroundStyle(.white)
            .padding(.vertical, 6).padding(.horizontal, 10)
            .background(.white.opacity(0.12), in: Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.15)))
    }
}

// MARK: - PARTICLES

struct SparkleField: View {
    @State private var t: CGFloat = 0
    var body: some View {
        TimelineView(.animation(minimumInterval: 1/30)) { _ in
            Canvas { ctx, size in
                let stars = 50
                for i in 0..<stars {
                    let x = CGFloat((i * 87) % Int(size.width == 0 ? 1 : size.width))
                    let y = CGFloat((i * 53) % Int(size.height == 0 ? 1 : size.height))
                    if let symbol = ctx.resolveSymbol(id: i) {
                        let pos = CGPoint(x: x, y: (y + t).truncatingRemainder(dividingBy: max(size.height, 1)))
                        ctx.draw(symbol, at: pos)
                    }
                }
            } symbols: {
                ForEach(0..<50, id: \.self) { i in
                    Circle().fill(.white.opacity(0.12 + Double(i % 5) * 0.05))
                        .frame(width: CGFloat(2 + (i % 4)), height: CGFloat(2 + (i % 4)))
                        .blur(radius: 0.5)
                }
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                t = 800
            }
        }
        .allowsHitTesting(false)
    }
}

struct TabItem: View {
    var icon: String
    var label: String
    var active: Bool
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(active ? .white : .white.opacity(0.6))
                .shadow(color: .black.opacity(0.6), radius: 8, y: 4)
            Text(label)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(active ? .white : .white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(active ? .white.opacity(0.06) : .clear, in: RoundedRectangle(cornerRadius: 14))
    }
}