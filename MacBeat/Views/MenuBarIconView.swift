import AppKit
import SwiftUI

struct MenuBarIconView: View {
    let isEnabled: Bool
    let isConnected: Bool

    var body: some View {
        Image(nsImage: MenuBarIconImage.make(isEnabled: isEnabled))
            .renderingMode(.template)
            .interpolation(.high)
            .antialiased(true)
            .frame(width: 18, height: 18)
            .accessibilityLabel(isEnabled ? "MacBeat On" : "MacBeat Off")
    }
}

private enum MenuBarIconImage {
    private static var cache: [Bool: NSImage] = [:]
    private static let onBase64 = "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"
    private static let offBase64 = "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"

    static func make(isEnabled: Bool) -> NSImage {
        if let cached = cache[isEnabled] {
            return cached
        }

        let image = assetImage(isEnabled: isEnabled)
        image.isTemplate = true
        image.size = NSSize(width: 18, height: 18)
        cache[isEnabled] = image
        return image
    }

    private static func assetImage(isEnabled: Bool) -> NSImage {
        let base64 = isEnabled ? onBase64 : offBase64
        if
            let data = Data(base64Encoded: base64),
            let image = NSImage(data: data)?.copy() as? NSImage
        {
            return image
        }

        return fallbackImage(isEnabled: isEnabled)
    }

    private static func fallbackImage(isEnabled: Bool) -> NSImage {
        let symbolName = isEnabled ? "waveform.circle.fill" : "slash.circle.fill"
        let image = NSImage(
            systemSymbolName: symbolName,
            accessibilityDescription: isEnabled ? "MacBeat On" : "MacBeat Off"
        ) ?? NSImage(size: NSSize(width: 18, height: 18))
        image.isTemplate = true
        image.size = NSSize(width: 18, height: 18)
        return image
    }
}
