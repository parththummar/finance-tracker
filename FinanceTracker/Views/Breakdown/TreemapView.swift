import SwiftUI

struct TreemapView: View {
    let tiles: [TreemapTile]
    var currency: Currency = .USD
    var total: Double = 0
    var onTap: (TreemapTile) -> Void = { _ in }
    var onHover: (TreemapTile?) -> Void = { _ in }

    @State private var hoverTile: TreemapTile?
    @State private var hoverPos: CGPoint?

    private let coordSpace = "treemap"
    private let tipSize = CGSize(width: 200, height: 78)

    var body: some View {
        GeometryReader { geo in
            let laid = TreemapLayout.layout(tiles: tiles, in: CGRect(origin: .zero, size: geo.size))
            let parents = collectParents(laid)
            let leaves = collectLeaves(laid)

            ZStack(alignment: .topLeading) {
                ZStack(alignment: .topLeading) {
                    ForEach(parents) { p in parentBackground(p) }
                    ForEach(leaves) { l in leafTile(l) }
                }
                .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
                .clipped()

                if let tile = hoverTile, let pos = hoverPos {
                    tooltipView(for: tile)
                        .frame(width: tipSize.width, height: tipSize.height, alignment: .leading)
                        .position(clampedTip(pos: pos, in: geo.size))
                        .allowsHitTesting(false)
                        .transition(.opacity.combined(with: .scale(scale: 0.97)))
                }
            }
            .coordinateSpace(name: coordSpace)
        }
    }

    private func collectParents(_ tiles: [TreemapTile]) -> [TreemapTile] {
        tiles.flatMap { t -> [TreemapTile] in
            t.children.isEmpty ? [] : [t] + collectParents(t.children)
        }
    }

    private func collectLeaves(_ tiles: [TreemapTile]) -> [TreemapTile] {
        tiles.flatMap { t -> [TreemapTile] in
            t.children.isEmpty ? [t] : collectLeaves(t.children)
        }
    }

    private func parentBackground(_ tile: TreemapTile) -> some View {
        ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(tile.color.opacity(0.22))
                .overlay(Rectangle().stroke(tile.color.opacity(0.9), lineWidth: 1.5))

            if tile.rect.height > 22 && tile.rect.width > 60 {
                Text(tile.label)
                    .font(.caption.bold())
                    .foregroundStyle(tile.color)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
            }
        }
        .frame(width: tile.rect.width, height: tile.rect.height, alignment: .topLeading)
        .offset(x: tile.rect.minX, y: tile.rect.minY)
        .contentShape(Rectangle())
        .onTapGesture { onTap(tile) }
        .onContinuousHover(coordinateSpace: .named(coordSpace)) { phase in
            switch phase {
            case .active(let loc):
                hoverTile = tile
                hoverPos = loc
                onHover(tile)
            case .ended:
                if hoverTile?.id == tile.id {
                    hoverTile = nil; hoverPos = nil; onHover(nil)
                }
            }
        }
    }

    private func leafTile(_ tile: TreemapTile) -> some View {
        let showLabel = tile.rect.width > 60 && tile.rect.height > 30
        return ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(tile.color.opacity(0.85))
                .overlay(Rectangle().stroke(.white.opacity(0.35), lineWidth: 1))
            if showLabel {
                VStack(alignment: .leading, spacing: 2) {
                    Text(tile.label)
                        .font(.caption.bold())
                        .lineLimit(1)
                    Text(Fmt.currency(tile.value, currency))
                        .font(.caption2.monospacedDigit())
                        .opacity(0.9)
                }
                .foregroundStyle(.white)
                .padding(6)
            }
        }
        .frame(width: tile.rect.width, height: tile.rect.height, alignment: .topLeading)
        .offset(x: tile.rect.minX, y: tile.rect.minY)
        .contentShape(Rectangle())
        .onTapGesture { onTap(tile) }
        .onContinuousHover(coordinateSpace: .named(coordSpace)) { phase in
            switch phase {
            case .active(let loc):
                hoverTile = tile
                hoverPos = loc
                onHover(tile)
            case .ended:
                if hoverTile?.id == tile.id {
                    hoverTile = nil; hoverPos = nil; onHover(nil)
                }
            }
        }
    }

    private func tooltipView(for tile: TreemapTile) -> some View {
        let pct = total > 0 ? tile.value / total * 100 : 0
        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(tile.color)
                    .frame(width: 8, height: 8)
                Text(tile.label)
                    .font(Typo.sans(12, weight: .semibold))
                    .foregroundStyle(Color.lInk)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Text("\(pct, specifier: "%.1f")%")
                    .font(Typo.mono(11, weight: .semibold))
                    .foregroundStyle(Color.lInk3)
                    .monospacedDigit()
            }
            Text(Fmt.currency(tile.value, currency))
                .font(Typo.mono(12.5, weight: .semibold))
                .foregroundStyle(Color.lInk)
                .monospacedDigit()
            if let nv = tile.nativeValue, let nc = tile.nativeCurrency, nc != currency {
                Text("native · \(Fmt.currency(nv, nc))")
                    .font(Typo.mono(10.5))
                    .foregroundStyle(Color.lInk3)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.lPanel)
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.lLine, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
    }

    private func clampedTip(pos: CGPoint, in container: CGSize) -> CGPoint {
        let margin: CGFloat = 8
        let offset: CGFloat = 14
        var x = pos.x + offset + tipSize.width / 2
        var y = pos.y + offset + tipSize.height / 2

        if x + tipSize.width / 2 + margin > container.width {
            x = pos.x - offset - tipSize.width / 2
        }
        if y + tipSize.height / 2 + margin > container.height {
            y = pos.y - offset - tipSize.height / 2
        }
        x = min(max(tipSize.width / 2 + margin, x), container.width - tipSize.width / 2 - margin)
        y = min(max(tipSize.height / 2 + margin, y), container.height - tipSize.height / 2 - margin)
        return CGPoint(x: x, y: y)
    }
}
