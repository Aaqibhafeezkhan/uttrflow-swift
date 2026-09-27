// The redesigned pages' tables: columns that line up, the header row and the hairline between rows.

import SwiftUI

/// A table column's width: fixed, or a share of what the fixed ones leave.
enum PageColumnWidth {
    case fixed(CGFloat)
    case share(CGFloat)
}

/// Lays a table row's cells out on the page's columns, so the header and every row line up.
struct PageColumns: Layout {
    let widths: [PageColumnWidth]
    var spacing: CGFloat = PageMetrics.columnSpacing

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 600
        let cells = cellWidths(in: width)
        let height =
            zip(subviews, cells).map {
                $0.sizeThatFits(ProposedViewSize(width: $1, height: nil)).height
            }.max() ?? 0
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        for (subview, width) in zip(subviews, cellWidths(in: bounds.width)) {
            subview.place(
                at: CGPoint(x: x, y: bounds.midY), anchor: .leading,
                proposal: ProposedViewSize(width: width, height: nil))
            x += width + spacing
        }
    }

    /// Each cell's width at a row width: the fixed ones first, the rest shared out.
    func cellWidths(in width: CGFloat) -> [CGFloat] {
        let gaps = spacing * CGFloat(max(widths.count - 1, 0))
        var fixed: CGFloat = 0
        var shares: CGFloat = 0
        for column in widths {
            switch column {
            case .fixed(let value): fixed += value
            case .share(let value): shares += value
            }
        }
        let left = max(width - gaps - fixed, 0)
        return widths.map {
            switch $0 {
            case .fixed(let value): value
            case .share(let value): shares > 0 ? left * value / shares : 0
            }
        }
    }
}

/// A table's header row, in the small capitalised label style.
struct PageTableHeader: View {
    let titles: [String]
    let widths: [PageColumnWidth]

    var body: some View {
        PageColumns(widths: widths) {
            ForEach(Array(titles.enumerated()), id: \.offset) { _, title in
                Text(title.uppercased()).lineLimit(1)
            }
        }
        .font(.system(size: 10.5, weight: .semibold))
        .tracking(0.63)
        .foregroundStyle(PagePalette.text.opacity(0.4))
        .padding(.horizontal, PageMetrics.rowInset)
        .padding(.vertical, 10)
        .accessibilityHidden(true)
    }
}

/// A hairline between table rows.
struct PageDivider: View {
    var body: some View {
        Rectangle()
            .fill(PagePalette.text.opacity(0.07))
            .frame(height: 1)
            .accessibilityHidden(true)
    }
}
