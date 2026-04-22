import SwiftUI

struct TreemapTile: Identifiable {
    let id: UUID
    let label: String
    let value: Double
    let color: Color
    let accountID: UUID?
    var rect: CGRect = .zero
    var children: [TreemapTile] = []

    init(id: UUID = UUID(), label: String, value: Double, color: Color, accountID: UUID? = nil, children: [TreemapTile] = []) {
        self.id = id
        self.label = label
        self.value = value
        self.color = color
        self.accountID = accountID
        self.children = children
    }
}

/// Squarified treemap (Bruls/Huijsen/van Wijk, 2000).
enum TreemapLayout {
    static func layout(tiles: [TreemapTile], in rect: CGRect) -> [TreemapTile] {
        guard !tiles.isEmpty, rect.width > 0, rect.height > 0 else { return [] }
        let total = tiles.map(\.value).reduce(0, +)
        guard total > 0 else { return [] }

        let scale = rect.width * rect.height / total
        let sorted = tiles.sorted { $0.value > $1.value }
            .map { tile -> TreemapTile in
                var t = tile; t.rect = .zero; return t
            }

        var placed: [TreemapTile] = []
        squarify(children: sorted, row: [], remaining: rect, scale: scale, output: &placed)
        return placed
    }

    private static func squarify(children: [TreemapTile],
                                 row: [TreemapTile],
                                 remaining: CGRect,
                                 scale: Double,
                                 output: inout [TreemapTile]) {
        let shortest = min(remaining.width, remaining.height)
        guard let first = children.first else {
            layoutRow(row: row, remaining: remaining, scale: scale, output: &output)
            return
        }

        let newRow = row + [first]
        let rest = Array(children.dropFirst())

        if row.isEmpty || worst(row: newRow, shortest: shortest, scale: scale)
                       <= worst(row: row, shortest: shortest, scale: scale) {
            squarify(children: rest, row: newRow, remaining: remaining, scale: scale, output: &output)
        } else {
            let (placedRow, leftover) = placeRow(row: row, remaining: remaining, scale: scale)
            output.append(contentsOf: placedRow)
            squarify(children: children, row: [], remaining: leftover, scale: scale, output: &output)
        }
    }

    private static func worst(row: [TreemapTile], shortest: Double, scale: Double) -> Double {
        let areas = row.map { $0.value * scale }
        let sum = areas.reduce(0, +)
        guard sum > 0 else { return .infinity }
        let rPlus = areas.max() ?? 0
        let rMinus = areas.min() ?? 0
        let s2 = shortest * shortest
        return max((s2 * rPlus) / (sum * sum), (sum * sum) / (s2 * rMinus))
    }

    private static func layoutRow(row: [TreemapTile], remaining: CGRect, scale: Double, output: inout [TreemapTile]) {
        let (placed, _) = placeRow(row: row, remaining: remaining, scale: scale)
        output.append(contentsOf: placed)
    }

    private static func nestChildren(of tile: TreemapTile, in parentRect: CGRect) -> [TreemapTile] {
        guard !tile.children.isEmpty else { return [] }
        let pad: CGFloat = 3
        let headerHeight: CGFloat = 18
        let innerRect = CGRect(
            x: parentRect.minX + pad,
            y: parentRect.minY + headerHeight,
            width: max(parentRect.width - pad * 2, 0),
            height: max(parentRect.height - headerHeight - pad, 0)
        )
        guard innerRect.width > 4, innerRect.height > 4 else { return [] }
        return TreemapLayout.layout(tiles: tile.children, in: innerRect)
    }

    private static func placeRow(row: [TreemapTile], remaining: CGRect, scale: Double)
        -> (placed: [TreemapTile], leftover: CGRect) {
        guard !row.isEmpty else { return ([], remaining) }
        let areas = row.map { $0.value * scale }
        let sum = areas.reduce(0, +)
        let horizontal = remaining.width >= remaining.height
        var placed: [TreemapTile] = []

        if horizontal {
            let rowHeight = sum / remaining.width
            var x = remaining.minX
            for (i, tile) in row.enumerated() {
                let w = areas[i] / rowHeight
                var t = tile
                t.rect = CGRect(x: x, y: remaining.minY, width: w, height: rowHeight)
                t.children = nestChildren(of: tile, in: t.rect)
                placed.append(t)
                x += w
            }
            let leftover = CGRect(x: remaining.minX, y: remaining.minY + rowHeight,
                                  width: remaining.width, height: remaining.height - rowHeight)
            return (placed, leftover)
        } else {
            let rowWidth = sum / remaining.height
            var y = remaining.minY
            for (i, tile) in row.enumerated() {
                let h = areas[i] / rowWidth
                var t = tile
                t.rect = CGRect(x: remaining.minX, y: y, width: rowWidth, height: h)
                t.children = nestChildren(of: tile, in: t.rect)
                placed.append(t)
                y += h
            }
            let leftover = CGRect(x: remaining.minX + rowWidth, y: remaining.minY,
                                  width: remaining.width - rowWidth, height: remaining.height)
            return (placed, leftover)
        }
    }
}
