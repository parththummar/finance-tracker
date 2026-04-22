import SwiftUI
import AppKit

// MARK: - Panel (replaces Card)

struct Panel<Content: View>: View {
    var padding: CGFloat = 0
    let content: () -> Content
    init(padding: CGFloat = 0, @ViewBuilder _ content: @escaping () -> Content) {
        self.padding = padding
        self.content = content
    }
    var body: some View {
        content()
            .padding(padding)
            .background(Color.lPanel)
            .overlay(
                RoundedRectangle(cornerRadius: 12).stroke(Color.lLine, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct PanelHead: View {
    let title: String
    var meta: String? = nil
    var body: some View {
        HStack {
            Text(title)
                .font(Typo.sans(14, weight: .semibold))
                .foregroundStyle(Color.lInk)
            Spacer()
            if let meta {
                Text(meta)
                    .font(Typo.sans(12))
                    .foregroundStyle(Color.lInk3)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .overlay(Rectangle().frame(height: 1).foregroundStyle(Color.lLine), alignment: .bottom)
    }
}

// MARK: - SectionHead (page-level)

struct SectionHead: View {
    let title: String
    var emphasis: String? = nil
    var subtitle: String? = nil
    var rightLabel: String? = nil

    var body: some View {
        HStack(alignment: .lastTextBaseline) {
            HStack(spacing: 6) {
                Text(title).font(Typo.serifNum(28))
                    .foregroundStyle(Color.lInk)
                if let emphasis {
                    Text(emphasis)
                        .font(Typo.serifItalic(28))
                        .foregroundStyle(Color.lInk3)
                }
            }
            Spacer()
            if let rightLabel {
                Text(rightLabel)
                    .font(Typo.eyebrow)
                    .textCase(.uppercase)
                    .tracking(1.2)
                    .foregroundStyle(Color.lInk3)
            }
        }
        if let subtitle {
            Text(subtitle)
                .font(Typo.serifItalic(14))
                .foregroundStyle(Color.lInk3)
                .padding(.top, 2)
        }
    }
}

struct PageHero: View {
    let eyebrow: String
    let title: String
    var titleItalic: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(eyebrow)
                .font(Typo.eyebrow)
                .textCase(.uppercase)
                .tracking(1.5)
                .foregroundStyle(Color.lInk3)
            HStack(spacing: 8) {
                Text(title).font(Typo.serifNum(38))
                if let titleItalic {
                    Text(titleItalic).font(Typo.serifItalic(38))
                        .foregroundStyle(Color.lInk3)
                }
            }
            .foregroundStyle(Color.lInk)
        }
    }
}

// MARK: - KPI card

struct KPICard: View {
    let label: String
    let value: String
    var sub: String? = nil
    var valueColor: Color = .lInk
    var deltaText: String? = nil
    var deltaUp: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(Typo.eyebrow)
                .textCase(.uppercase)
                .tracking(1.2)
                .foregroundStyle(Color.lInk3)
            Text(value)
                .font(Typo.serifNum(34))
                .foregroundStyle(valueColor)
                .monospacedDigit()
            if let sub {
                HStack(spacing: 4) {
                    Text(sub)
                        .font(Typo.sans(11))
                        .foregroundStyle(Color.lInk3)
                    if let deltaText {
                        Text(deltaText)
                            .font(Typo.mono(11, weight: .medium))
                            .foregroundStyle(deltaUp ? Color.lGain : Color.lLoss)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color.lPanel)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.lLine, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Allocation row (swatch + label + value + pct + bar)

struct AllocRow: View {
    let color: Color
    let label: String
    let value: String
    let pct: Double
    var showBar: Bool = false
    var valueColor: Color = .lInk

    var body: some View {
        VStack(spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(color)
                    .frame(width: 10, height: 10)
                Text(label)
                    .font(Typo.sans(13, weight: .medium))
                    .foregroundStyle(Color.lInk)
                Spacer()
                Text(value)
                    .font(Typo.sans(13, weight: .semibold))
                    .foregroundStyle(valueColor)
                    .monospacedDigit()
                Text("\(pct, specifier: "%.1f")%")
                    .font(Typo.sans(12))
                    .foregroundStyle(Color.lInk3)
                    .monospacedDigit()
                    .frame(width: 50, alignment: .trailing)
            }
            if showBar {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle().fill(Color.lSunken)
                        Rectangle().fill(color)
                            .frame(width: max(0, geo.size.width * CGFloat(pct / 100)))
                    }
                }
                .frame(height: 4)
                .clipShape(RoundedRectangle(cornerRadius: 2))
            }
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Hero delta pill

struct HeroDelta: View {
    let pct: Double
    let suffix: String
    var body: some View {
        let up = pct >= 0
        HStack(spacing: 6) {
            Image(systemName: up ? "arrow.up.right" : "arrow.down.right")
                .font(.system(size: 9, weight: .bold))
            Text("\(up ? "+" : "−")\(abs(pct), specifier: "%.2f")%")
                .font(Typo.mono(12, weight: .semibold))
            Text(suffix)
                .font(Typo.mono(11))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background((up ? Color.lGain : Color.lLoss).opacity(0.12))
        .foregroundStyle(up ? Color.lGain : Color.lLoss)
        .overlay(Capsule().stroke((up ? Color.lGain : Color.lLoss).opacity(0.35), lineWidth: 1))
        .clipShape(Capsule())
    }
}

// MARK: - Avatar (colored disk with initials)

struct Avatar: View {
    let text: String
    var color: Color
    var size: CGFloat = 22

    var body: some View {
        ZStack {
            Circle().fill(color.opacity(0.18))
            Circle().stroke(color.opacity(0.55), lineWidth: 1)
            Text(text)
                .font(Typo.sans(size * 0.42, weight: .semibold))
                .foregroundStyle(color)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Pill

struct Pill: View {
    let text: String
    var emphasis: Bool = false
    var body: some View {
        Text(text)
            .font(Typo.mono(10.5, weight: .medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(emphasis ? Color.lInk : Color.clear)
            .foregroundStyle(emphasis ? Color.lPanel : Color.lInk2)
            .overlay(Capsule().stroke(emphasis ? Color.lInk : Color.lLine, lineWidth: 1))
            .clipShape(Capsule())
    }
}

struct RateChip: View {
    let leading: String
    let trailing: String
    var body: some View {
        HStack(spacing: 6) {
            Text(leading)
                .font(Typo.mono(10.5))
                .foregroundStyle(Color.lInk3)
            Text(trailing)
                .font(Typo.mono(11, weight: .semibold))
                .foregroundStyle(Color.lInk)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .overlay(Capsule().stroke(Color.lLine, lineWidth: 1))
    }
}

// MARK: - Segmented control (mono, ink)

struct SegControl<T: Hashable>: View {
    let options: [(label: String, value: T)]
    @Binding var selection: T

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(options.enumerated()), id: \.offset) { idx, opt in
                Button {
                    selection = opt.value
                } label: {
                    Text(opt.label)
                        .font(Typo.mono(10.5, weight: .semibold))
                        .foregroundStyle(selection == opt.value ? Color.lPanel : Color.lInk2)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(selection == opt.value ? Color.lInk : Color.lPanel.opacity(0.001))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if idx < options.count - 1 {
                    Rectangle().fill(Color.lLine).frame(width: 1, height: 18)
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .overlay(Capsule().stroke(Color.lLine, lineWidth: 1))
        .clipShape(Capsule())
    }
}

// MARK: - Primary / Ghost / Icon buttons

struct PrimaryButton<Label: View>: View {
    let action: () -> Void
    let label: () -> Label
    init(action: @escaping () -> Void, @ViewBuilder label: @escaping () -> Label) {
        self.action = action; self.label = label
    }
    var body: some View {
        Button(action: action) {
            label()
                .font(Typo.sans(12, weight: .semibold))
                .foregroundStyle(Color.lPanel)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Color.lInk)
                .clipShape(Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct GhostButton<Label: View>: View {
    let action: () -> Void
    let label: () -> Label
    init(action: @escaping () -> Void, @ViewBuilder label: @escaping () -> Label) {
        self.action = action; self.label = label
    }
    var body: some View {
        Button(action: action) {
            label()
                .font(Typo.sans(12, weight: .medium))
                .foregroundStyle(Color.lInk)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.lPanel.opacity(0.001))
                .overlay(Capsule().stroke(Color.lLine, lineWidth: 1))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct IconButton: View {
    let systemName: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.lInk2)
                .frame(width: 28, height: 28)
                .background(Color.lPanel.opacity(0.001))
                .overlay(Circle().stroke(Color.lLine, lineWidth: 1))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Stacked horizontal bar

struct StackedHBar: View {
    struct Item: Identifiable {
        let id = UUID()
        let label: String
        let value: Double
        let color: Color
    }
    let items: [Item]
    var height: CGFloat = 14

    var body: some View {
        let total = max(0.0001, items.reduce(0) { $0 + abs($1.value) })
        GeometryReader { geo in
            HStack(spacing: 1) {
                ForEach(items) { i in
                    Rectangle()
                        .fill(i.color)
                        .frame(width: geo.size.width * CGFloat(abs(i.value) / total) - 1)
                }
            }
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: 3))
    }
}

// MARK: - ColorSwatchButton (inline color editor)

struct ColorSwatchButton: View {
    let current: Color
    let onPick: (Color) -> Void
    var size: CGFloat = 14
    @State private var open = false
    @State private var custom: Color = .blue
    @State private var customArmed = false

    var body: some View {
        Button {
            custom = current
            customArmed = false
            open = true
        } label: {
            Circle()
                .fill(current)
                .frame(width: size, height: size)
                .overlay(Circle().stroke(Color.lLine, lineWidth: 0.5))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .popover(isPresented: $open, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 12) {
                Text("PICK COLOR")
                    .font(Typo.eyebrow).tracking(1.2)
                    .foregroundStyle(Color.lInk3)
                LazyVGrid(
                    columns: Array(repeating: GridItem(.fixed(24), spacing: 10), count: 7),
                    spacing: 10
                ) {
                    ForEach(0..<Ink.chart.count, id: \.self) { i in
                        let c = Ink.chart[i].color
                        Button {
                            onPick(c)
                            open = false
                        } label: {
                            Circle()
                                .fill(c)
                                .frame(width: 24, height: 24)
                                .overlay(Circle().stroke(Color.lLine, lineWidth: 1))
                                .contentShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                Divider().overlay(Color.lLine)
                HStack(spacing: 10) {
                    ColorPicker("", selection: $custom, supportsOpacity: false)
                        .labelsHidden()
                    Text("Custom")
                        .font(Typo.sans(12))
                        .foregroundStyle(Color.lInk2)
                    Spacer()
                    PrimaryButton(action: {
                        onPick(custom)
                        NSColorPanel.shared.close()
                        open = false
                    }) { Text("Apply") }
                }
            }
            .padding(14)
            .frame(width: 260)
            .background(Color.lPanel)
            .onChange(of: custom) { _, newVal in
                guard open else { return }
                guard customArmed else { customArmed = true; return }
                onPick(newVal)
                NSColorPanel.shared.close()
                open = false
            }
        }
        .onChange(of: open) { _, isOpen in
            if !isOpen { NSColorPanel.shared.close() }
        }
    }
}

// MARK: - Text helpers

extension View {
    func tabularMono() -> some View {
        self.font(Typo.mono(12)).monospacedDigit()
    }
}
