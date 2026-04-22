import SwiftUI
import AppKit

enum Palette {
    static func defaultColor(for category: AssetCategory) -> Color {
        switch category {
        case .retirement: return Color(red: 0.23, green: 0.51, blue: 0.96)
        case .investment: return Color(red: 0.08, green: 0.72, blue: 0.65)
        case .cash:       return Color(red: 0.96, green: 0.62, blue: 0.04)
        case .crypto:     return Color(red: 0.55, green: 0.36, blue: 0.96)
        case .insurance:  return Color(red: 0.42, green: 0.45, blue: 0.50)
        case .debt:       return Color(red: 0.96, green: 0.25, blue: 0.37)
        }
    }

    static func color(for category: AssetCategory) -> Color {
        Color.fromHex(CategoryColorStore.hex(for: category)) ?? defaultColor(for: category)
    }

    static func fallback(for key: String) -> Color {
        let colors: [Color] = [.blue, .orange, .teal, .purple, .pink, .green, .red, .yellow]
        return colors[abs(key.hashValue) % colors.count]
    }

    static let up   = Color(red: 0.13, green: 0.64, blue: 0.29)
    static let down = Color(red: 0.86, green: 0.15, blue: 0.15)

    static func deltaColor(_ value: Double) -> Color {
        value >= 0 ? up : down
    }
}

extension Color {
    static func fromHex(_ hex: String?) -> Color? {
        guard let hex, !hex.isEmpty else { return nil }
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let val = UInt32(s, radix: 16) else { return nil }
        let r = Double((val >> 16) & 0xFF) / 255
        let g = Double((val >> 8) & 0xFF) / 255
        let b = Double(val & 0xFF) / 255
        return Color(red: r, green: g, blue: b)
    }

    func toHex() -> String? {
        let ns = NSColor(self).usingColorSpace(.sRGB) ?? NSColor(self)
        let r = Int(round(ns.redComponent * 255))
        let g = Int(round(ns.greenComponent * 255))
        let b = Int(round(ns.blueComponent * 255))
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

enum CategoryColorStore {
    private static let keyPrefix = "categoryColor."

    static func hex(for category: AssetCategory) -> String? {
        UserDefaults.standard.string(forKey: keyPrefix + category.rawValue)
    }

    static func setHex(_ hex: String?, for category: AssetCategory) {
        let key = keyPrefix + category.rawValue
        if let hex { UserDefaults.standard.set(hex, forKey: key) }
        else { UserDefaults.standard.removeObject(forKey: key) }
    }
}

struct Card<Content: View>: View {
    let content: () -> Content
    init(@ViewBuilder _ content: @escaping () -> Content) { self.content = content }
    var body: some View {
        content()
            .padding(16)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.15), lineWidth: 1)
            )
    }
}
