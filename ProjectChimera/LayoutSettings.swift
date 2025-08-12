import Foundation
import SwiftUI

enum LayoutMode: String, CaseIterable, Identifiable {
    case system
    case mobile
    case desktop
    
    var id: String { rawValue }
    
    var label: String {
        switch self {
        case .system: return "System"
        case .mobile: return "Mobile"
        case .desktop: return "Desktop"
        }
    }
}

final class LayoutSettings: ObservableObject {
    static let shared = LayoutSettings()
    private static let modeKey = "layout_mode"
    
    @Published var mode: LayoutMode {
        didSet {
            UserDefaults.standard.set(mode.rawValue, forKey: Self.modeKey)
        }
    }
    
    private init() {
        if let raw = UserDefaults.standard.string(forKey: Self.modeKey),
           let saved = LayoutMode(rawValue: raw) {
            self.mode = saved
        } else {
            self.mode = .system
        }
    }
    
    var isForcedMobile: Bool { mode == .mobile }
    var isForcedDesktop: Bool { mode == .desktop }
}