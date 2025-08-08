import SwiftUI

/// A view that renders the user's Chimera based on its current parts.
/// This view is now shared and can be used by CharacterView, LairView, etc.
struct ChimeraView: View {
    let chimera: Chimera
    
    var body: some View {
        ZStack {
            auraPart(for: chimera.auraEffectID)
                .font(.system(size: 120))
                .blur(radius: 10)
            
            bodyPart(for: chimera.bodyPartID)
                .font(.system(size: 100))
            
            headPart(for: chimera.headPartID)
                .font(.system(size: 60))
                .offset(y: -45)
        }
    }
    
    /// Renders the aura part of the Chimera.
    @ViewBuilder
    private func auraPart(for id: String) -> some View {
        switch id {
        case "aura_subtle_t1":
            Circle().fill(Color.blue.gradient)
        case "aura_strong_t2":
            Circle().fill(Color.purple.gradient)
        default:
            EmptyView()
        }
    }
    
    /// Renders the body part of the Chimera.
    @ViewBuilder
    private func bodyPart(for id: String) -> some View {
        switch id {
        case "body_armor_t1":
            Image(systemName: "shield.lefthalf.filled")
        case "body_armor_t2":
            Image(systemName: "shield.fill")
        case "body_vibrant_t1":
            Image(systemName: "sparkles.circle.fill").foregroundColor(.orange)
        default:
            Image(systemName: "pawprint.circle.fill")
        }
    }
    
    /// Renders the head part of the Chimera.
    @ViewBuilder
    private func headPart(for id: String) -> some View {
        switch id {
        case "head_runes_t1":
            Image(systemName: "sparkles")
        case "head_runes_t2":
            Image(systemName: "crown.fill")
        case "head_feathers_t2":
            Image(systemName: "feather.circle.fill").foregroundColor(.yellow)
        default:
            Image(systemName: "pawprint.circle.fill").offset(y: 5)
        }
    }
}
