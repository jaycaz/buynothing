import SwiftUI

/// Background behind transparent cutouts so alpha reads clearly.
struct CheckerboardView: View {
    var cell: CGFloat = 10

    var body: some View {
        Canvas { context, size in
            let cols = Int(ceil(size.width / cell))
            let rows = Int(ceil(size.height / cell))
            for row in 0..<rows {
                for col in 0..<cols {
                    let isLight = (row + col).isMultiple(of: 2)
                    let rect = CGRect(x: CGFloat(col) * cell, y: CGFloat(row) * cell, width: cell, height: cell)
                    context.fill(Path(rect), with: .color(isLight ? Color(white: 0.93) : Color(white: 0.83)))
                }
            }
        }
    }
}
