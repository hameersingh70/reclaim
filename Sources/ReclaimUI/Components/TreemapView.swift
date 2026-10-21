// TreemapView.swift
// ReclaimUI/Components
//
// Native SwiftUI Hierarchical Treemap Component.
// Renders proportional rectangular tiles sized according to file/directory byte allocation.
// Supports interactive hover tooltips, color-coded developer categories, and drill-down selection.

import SwiftUI
import Reclaim

public struct TreemapNode: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let path: String
    public let value: Int64
    public let color: Color
    public let categoryName: String

    public init(
        id: String = UUID().uuidString,
        name: String,
        path: String,
        value: Int64,
        color: Color,
        categoryName: String
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.value = value
        self.color = color
        self.categoryName = categoryName
    }

    public var formattedValue: String {
        ByteCountFormatter.string(fromByteCount: value, countStyle: .file)
    }
}

public struct TreemapView: View {
    public let nodes: [TreemapNode]
    public let theme: any Theme
    public let onSelect: (TreemapNode) -> Void

    @State private var hoveredNode: TreemapNode? = nil

    public init(nodes: [TreemapNode], theme: any Theme, onSelect: @escaping (TreemapNode) -> Void) {
        self.nodes = nodes.sorted { $0.value > $1.value }
        self.theme = theme
        self.onSelect = onSelect
    }

    private var totalValue: Int64 {
        nodes.reduce(0) { $0 + $1.value }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Hover Tooltip / Header
            HStack {
                if let hover = hoveredNode {
                    HStack(spacing: 8) {
                        Circle().fill(hover.color).frame(width: 8, height: 8)
                        Text(hover.name)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(theme.primaryText)
                        Text(hover.formattedValue)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(theme.accent)
                        Text(hover.categoryName)
                            .font(.system(size: 11))
                            .foregroundColor(theme.secondaryText)
                    }
                } else {
                    Text("Hover over a block to inspect allocation details. Click to reveal.")
                        .font(.system(size: 12))
                        .foregroundColor(theme.secondaryText)
                }
                Spacer()
            }
            .frame(height: 20)
            .padding(.horizontal, 4)

            // Geometry-Driven Tiling Layout
            GeometryReader { geometry in
                let rects = computeLayout(in: CGRect(origin: .zero, size: geometry.size))
                ZStack(alignment: .topLeading) {
                    ForEach(Array(zip(nodes, rects)), id: \.0.id) { node, rect in
                        TreemapTile(
                            node: node,
                            rect: rect,
                            isHovered: hoveredNode?.id == node.id,
                            theme: theme
                        )
                        .onHover { isHovering in
                            if isHovering { hoveredNode = node }
                            else if hoveredNode?.id == node.id { hoveredNode = nil }
                        }
                        .onTapGesture {
                            onSelect(node)
                        }
                    }
                }
            }
        }
    }

    // Binary / Alternating slice subdivision
    private func computeLayout(in rect: CGRect) -> [CGRect] {
        guard !nodes.isEmpty, totalValue > 0 else { return [] }
        return layoutSlice(nodes: nodes, rect: rect, isHorizontal: rect.width > rect.height)
    }

    private func layoutSlice(nodes: [TreemapNode], rect: CGRect, isHorizontal: Bool) -> [CGRect] {
        guard !nodes.isEmpty else { return [] }
        if nodes.count == 1 { return [rect] }

        let total = nodes.reduce(0) { $0 + $1.value }
        guard total > 0 else { return Array(repeating: .zero, count: nodes.count) }

        // Find split point close to half weight
        var half: Int64 = 0
        var splitIndex = 0
        for (i, node) in nodes.enumerated() {
            half += node.value
            if half >= total / 2 || i == nodes.count - 2 {
                splitIndex = i + 1
                break
            }
        }

        let firstHalfNodes = Array(nodes[0..<splitIndex])
        let secondHalfNodes = Array(nodes[splitIndex..<nodes.count])

        let firstHalfWeight = firstHalfNodes.reduce(0) { $0 + $1.value }
        let fraction = CGFloat(firstHalfWeight) / CGFloat(total)

        var r1: CGRect = .zero
        var r2: CGRect = .zero

        if isHorizontal {
            let splitWidth = rect.width * fraction
            r1 = CGRect(x: rect.minX, y: rect.minY, width: splitWidth, height: rect.height)
            r2 = CGRect(x: rect.minX + splitWidth, y: rect.minY, width: rect.width - splitWidth, height: rect.height)
        } else {
            let splitHeight = rect.height * fraction
            r1 = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: splitHeight)
            r2 = CGRect(x: rect.minX, y: rect.minY + splitHeight, width: rect.width, height: rect.height - splitHeight)
        }

        let rects1 = layoutSlice(nodes: firstHalfNodes, rect: r1, isHorizontal: !isHorizontal)
        let rects2 = layoutSlice(nodes: secondHalfNodes, rect: r2, isHorizontal: !isHorizontal)
        return rects1 + rects2
    }
}

// MARK: - Tile

private struct TreemapTile: View {
    let node: TreemapNode
    let rect: CGRect
    let isHovered: Bool
    let theme: any Theme

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 4)
                .fill(node.color.opacity(isHovered ? 0.85 : 0.65))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isHovered ? Color.white : theme.background, lineWidth: isHovered ? 2 : 1)
                )

            if rect.width > 55 && rect.height > 35 {
                VStack(alignment: .leading, spacing: 2) {
                    Text(node.name)
                        .font(.system(size: rect.width > 90 ? 11 : 9, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    if rect.height > 48 {
                        Text(node.formattedValue)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.white.opacity(0.85))
                    }
                }
                .padding(6)
            }
        }
        .frame(width: max(rect.width, 0), height: max(rect.height, 0))
        .offset(x: rect.minX, y: rect.minY)
    }
}
