import SwiftUI
import SwiftData

@available(macOS 14.0, iOS 17.0, *)
struct LairView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var user: User?
    
    var body: some View {
        VStack {
            if let user = user, let chimera = user.chimera {
                WardrobeView(chimera: chimera)
            } else {
                ContentUnavailableView("No Chimera Found", systemImage: "pawprint.slash")
            }
        }
        .navigationTitle("Chimera's Lair")
        .onAppear {
            loadUser()
        }
    }
    
    private func loadUser() {
        let descriptor = FetchDescriptor<User>()
        do {
            let users = try modelContext.fetch(descriptor)
            user = users.first
        } catch {
            print("Failed to fetch user: \(error)")
        }
    }
}

// MARK: - Wardrobe View
@available(macOS 14.0, iOS 17.0, *)
struct WardrobeView: View {
    @Bindable var chimera: Chimera
    
    // Simple list of available cosmetic items
    let cosmeticItems = ["item_hat_wizard", "item_hat_party", "none"]

    var body: some View {
        VStack {
            Text("Wardrobe")
                .font(.title2).bold()
                .padding(.top)
            
            Picker("Equip Cosmetic", selection: $chimera.cosmeticHeadItemID) {
                ForEach(cosmeticItems, id: \.self) { item in
                    Text(item.replacingOccurrences(of: "item_hat_", with: "").capitalized).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            
            // The ZStack now correctly layers the Chimera and the selected cosmetic item.
            ZStack {
                // This now works because ChimeraView is accessible.
                ChimeraView(chimera: chimera)
                    .font(.system(size: 150))
                    .padding(.vertical, 40)
                
                if chimera.cosmeticHeadItemID != "none" {
                    cosmeticPart(for: chimera.cosmeticHeadItemID)
                        .font(.system(size: 60))
                        .offset(y: -100) // Adjust position as needed
                }
            }
            
            Spacer()
        }
    }
    
    /// A view builder for rendering cosmetic parts based on their ID.
    @ViewBuilder
    private func cosmeticPart(for id: String) -> some View {
        switch id {
        case "item_hat_wizard":
            Image(systemName: "graduationcap.fill").foregroundColor(.purple)
        case "item_hat_party":
            Image(systemName: "party.popper.fill").foregroundColor(.yellow)
        default:
            EmptyView()
        }
    }
}

#Preview {
    // We must create a dummy User in a temporary in-memory container for the preview to work.
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: User.self, configurations: config)
    
    let user = User(username: "PreviewUser")
    container.mainContext.insert(user)
    
    return NavigationStack {
        LairView()
    }
    .modelContainer(container)
}
