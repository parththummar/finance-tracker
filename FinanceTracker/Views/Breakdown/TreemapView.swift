import SwiftUI

struct TreemapView: View {
    let tiles: [TreemapTile]
    var currency: Currency = .USD
    var onTap: (TreemapTile) -> Void = { _ in }
    var onHover: (TreemapTile?) -> Void = { _ in }

    var body: some View {
        GeometryReader { geo in
            let laid = TreemapLayout.layout(tiles: tiles, in: CGRect(origin: .zero, size: geo.size))
            let parents = collectParents(laid)
            let leaves = collectLeaves(laid)

            ZStack(alignment: .topLeading) {
                ForEach(parents) { p in parentBackground(p) }
                ForEach(leaves) { l in leafTile(l) }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
            .clipped()
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
        .onTapGesture { onTap(tile) }
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
        .help("\(tile.label) — \(Fmt.currency(tile.value, currency))")
        .onTapGesture { onTap(tile) }
        .onHover { hovering in onHover(hovering ? tile : nil) }
    }
}
