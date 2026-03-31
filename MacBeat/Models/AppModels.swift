import Foundation
import SwiftUI

enum SensorConnectionState: String {
    case disconnected
    case searching
    case connected
    case unsupported
    case failed

    var label: String {
        switch self {
        case .disconnected:
            return "Offline"
        case .searching:
            return "Searching"
        case .connected:
            return "Live"
        case .unsupported:
            return "Unsupported"
        case .failed:
            return "Needs Access"
        }
    }
}

enum ChassisRegion: String, CaseIterable, Identifiable {
    case top
    case left
    case right
    case bottom
    case center

    var id: String { rawValue }

    var title: String {
        rawValue.capitalized
    }

    var systemImage: String {
        switch self {
        case .top:
            return "arrow.up.circle.fill"
        case .left:
            return "arrow.left.circle.fill"
        case .right:
            return "arrow.right.circle.fill"
        case .bottom:
            return "arrow.down.circle.fill"
        case .center:
            return "circle.fill"
        }
    }

    var accent: Color {
        switch self {
        case .top:
            return .cyan
        case .left:
            return .orange
        case .right:
            return .pink
        case .bottom:
            return .green
        case .center:
            return .purple
        }
    }
}

struct AccelSample {
    let x: Double
    let y: Double
    let z: Double
    let dynamicMagnitude: Double
    let timestamp: TimeInterval

    static let zero = AccelSample(x: 0, y: 0, z: 0, dynamicMagnitude: 0, timestamp: 0)

    var vector: SIMD3<Double> {
        SIMD3(x, y, z)
    }
}

struct HitEvent: Identifiable {
    let id = UUID()
    let timestamp: TimeInterval
    let intensity: Double
    let confidence: Double
    let vector: SIMD3<Double>
    let region: ChassisRegion
}

struct PlayedPad {
    let padID: String
    let kitID: String
    let region: ChassisRegion
    let role: PadRole
    let intensity: Double
    let timestamp: TimeInterval
}

enum PadRole: String {
    case kick
    case snare
    case hat
    case accent

    static let mappableCases: [PadRole] = [.kick, .snare, .hat]

    var title: String {
        switch self {
        case .kick:
            return "Kick"
        case .snare:
            return "Snare"
        case .hat:
            return "Hat"
        case .accent:
            return "Accent"
        }
    }

    var shortTitle: String {
        switch self {
        case .kick:
            return "Bass"
        case .snare:
            return "Snare"
        case .hat:
            return "Hi-Hat"
        case .accent:
            return "Accent"
        }
    }

    var accentColor: Color {
        switch self {
        case .kick:
            return Color(red: 0.18, green: 0.68, blue: 0.43)
        case .snare:
            return Color(red: 0.96, green: 0.56, blue: 0.24)
        case .hat:
            return Color(red: 0.16, green: 0.50, blue: 0.96)
        case .accent:
            return Color(red: 0.69, green: 0.44, blue: 0.95)
        }
    }
}

enum SurfaceZone: String, CaseIterable, Identifiable {
    case left
    case center
    case right

    var id: String { rawValue }

    var title: String {
        switch self {
        case .left:
            return "Left"
        case .center:
            return "Middle"
        case .right:
            return "Right"
        }
    }

    var subtitle: String {
        switch self {
        case .left:
            return "Left side"
        case .center:
            return "Touchpad zone"
        case .right:
            return "Right side"
        }
    }

    var systemImage: String {
        switch self {
        case .left:
            return "rectangle.leadinghalf.inset.filled.arrow.leading"
        case .center:
            return "rectangle.center.inset.filled"
        case .right:
            return "rectangle.trailinghalf.inset.filled.arrow.trailing"
        }
    }
}

enum ShortcutMapping: String, CaseIterable, Identifiable {
    case none
    case screenshot
    case mute
    case screenshotAndMute

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none:
            return "Off"
        case .screenshot:
            return "Double-slap: Screenshot"
        case .mute:
            return "Double-slap: Mute"
        case .screenshotAndMute:
            return "Double-slap: Screenshot + Mute"
        }
    }
}

struct DrumPad: Identifiable {
    let id: String
    let name: String
    let region: ChassisRegion
    let role: PadRole
    let color: Color
    let placeholderFileName: String
    let sampleFolder: String
}

struct DrumKit: Identifiable {
    let id: String
    let name: String
    let subtitle: String
    let systemImage: String
    let gradient: [Color]
    let pads: [DrumPad]
}
