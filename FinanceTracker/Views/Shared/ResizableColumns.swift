import SwiftUI
import AppKit
import Combine

struct ColumnSpec: Identifiable, Hashable {
    let id: String
    let title: String
    let minWidth: CGFloat
    let defaultWidth: CGFloat
    var alignment: TextAlignment = .leading
    var flex: Bool = false
    var resizable: Bool = true
}

final class ColumnSizer: ObservableObject {
    let tableID: String
    let specs: [ColumnSpec]
    @Published private(set) var widths: [String: CGFloat] = [:]
    @Published private(set) var titleOverrides: [String: String] = [:]

    init(tableID: String, specs: [ColumnSpec]) {
        self.tableID = tableID
        self.specs = specs
        for s in specs {
            let stored = UserDefaults.standard.double(forKey: Self.key(tableID, s.id))
            widths[s.id] = stored > 0 ? max(stored, s.minWidth) : s.defaultWidth
        }
    }

    func setTitle(_ id: String, _ title: String?) {
        if let title { titleOverrides[id] = title } else { titleOverrides.removeValue(forKey: id) }
    }

    func title(for id: String) -> String {
        titleOverrides[id] ?? specs.first(where: { $0.id == id })?.title ?? id
    }

    private static func key(_ tableID: String, _ colID: String) -> String {
        "col.\(tableID).\(colID)"
    }

    func width(_ id: String) -> CGFloat {
        widths[id] ?? specs.first(where: { $0.id == id })?.defaultWidth ?? 100
    }

    func set(_ id: String, _ width: CGFloat) {
        guard let spec = specs.first(where: { $0.id == id }) else { return }
        let clamped = max(spec.minWidth, width)
        widths[id] = clamped
        UserDefaults.standard.set(clamped, forKey: Self.key(tableID, id))
    }

    func reset() {
        for s in specs {
            widths[s.id] = s.defaultWidth
            UserDefaults.standard.removeObject(forKey: Self.key(tableID, s.id))
        }
    }
}

private struct ColAlignment {
    static func swiftUI(_ a: TextAlignment) -> Alignment {
        switch a {
        case .leading:  return .leading
        case .center:   return .center
        case .trailing: return .trailing
        }
    }
}

struct ResizableHeader: View {
    @ObservedObject var sizer: ColumnSizer

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(sizer.specs.enumerated()), id: \.element.id) { idx, spec in
                ZStack(alignment: .trailing) {
                    Text(sizer.title(for: spec.id))
                        .font(Typo.eyebrow).tracking(1.2)
                        .foregroundStyle(Color.lInk3)
                        .frame(maxWidth: .infinity,
                               alignment: ColAlignment.swiftUI(spec.alignment))
                        .lineLimit(1)
                        .padding(.horizontal, 8)
                    if spec.resizable && idx < sizer.specs.count - 1 {
                        ResizeHandle(sizer: sizer, colID: spec.id)
                    }
                }
                .applyWidth(spec: spec, sizer: sizer)
            }
        }
        .padding(.horizontal, 18).padding(.vertical, 10)
        .fixedSize(horizontal: false, vertical: true)
        .background(Color.lSunken)
        .overlay(Rectangle().frame(height: 1).foregroundStyle(Color.lLine), alignment: .bottom)
    }
}

struct ResizableCell<Content: View>: View {
    @ObservedObject var sizer: ColumnSizer
    let colID: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        guard let spec = sizer.specs.first(where: { $0.id == colID }) else {
            return AnyView(content())
        }
        return AnyView(
            content()
                .frame(maxWidth: .infinity,
                       alignment: ColAlignment.swiftUI(spec.alignment))
                .padding(.horizontal, 8)
                .applyWidth(spec: spec, sizer: sizer)
        )
    }
}

private struct ResizeHandle: View {
    @ObservedObject var sizer: ColumnSizer
    let colID: String
    @State private var start: CGFloat?

    var body: some View {
        Rectangle()
            .fill(Color.clear)
            .frame(width: 10)
            .contentShape(Rectangle())
            .overlay(alignment: .center) {
                Rectangle()
                    .fill(Color.lLine.opacity(0.7))
                    .frame(width: 1)
            }
            .onHover { h in
                if h { NSCursor.resizeLeftRight.push() } else { NSCursor.pop() }
            }
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .global)
                    .onChanged { g in
                        if start == nil { start = sizer.width(colID) }
                        sizer.set(colID, (start ?? 0) + g.translation.width)
                    }
                    .onEnded { _ in start = nil }
            )
    }
}

private extension View {
    @ViewBuilder
    func applyWidth(spec: ColumnSpec, sizer: ColumnSizer) -> some View {
        if spec.flex {
            self.frame(minWidth: spec.minWidth, maxWidth: .infinity)
        } else {
            self.frame(width: sizer.width(spec.id))
        }
    }
}
