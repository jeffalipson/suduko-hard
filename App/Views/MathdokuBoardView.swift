import SwiftUI
import SudokuCore
import SudokuGame

/// The n×n Mathdoku grid: thick lines between cages, each cage's clue in its top-left cell, and the
/// same highlights, colours, notes and hint marks as the Sudoku board.
struct MathdokuBoardView: View {
    let session: MathdokuSession
    let settings: GameSettings
    /// Hint overlays: cells to spotlight and candidates the step removes (red).
    var spotlight: Set<Int> = []
    var marks: [CellDigit] = []
    let onTap: (Int) -> Void

    private var n: Int { session.n }

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            Canvas { ctx, _ in draw(in: &ctx, side: size) }
                .frame(width: size, height: size)
                .contentShape(Rectangle())
                .gesture(SpatialTapGesture().onEnded { tap in
                    let cell = size / CGFloat(n)
                    let r = min(n - 1, max(0, Int(tap.location.y / cell)))
                    let c = min(n - 1, max(0, Int(tap.location.x / cell)))
                    onTap(r * n + c)
                })
                .accessibilityElement(children: .contain)
                .accessibilityChildren {
                    Grid(horizontalSpacing: 0, verticalSpacing: 0) {
                        ForEach(0..<n, id: \.self) { r in
                            GridRow {
                                ForEach(0..<n, id: \.self) { c in
                                    let cell = r * n + c
                                    Rectangle()
                                        .frame(width: size / CGFloat(n), height: size / CGFloat(n))
                                        .accessibilityLabel(session.spokenDescription(of: cell))
                                        .accessibilityAddTraits(session.selected == cell ? [.isButton, .isSelected] : .isButton)
                                        .accessibilityAction { onTap(cell) }
                                }
                            }
                        }
                    }
                }
                .accessibilityIdentifier("board")
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func rect(_ cell: Int, _ unit: CGFloat) -> CGRect {
        CGRect(x: CGFloat(cell % n) * unit, y: CGFloat(cell / n) * unit, width: unit, height: unit)
    }

    private func draw(in ctx: inout GraphicsContext, side: CGFloat) {
        let unit = side / CGFloat(n)
        ctx.fill(Path(CGRect(x: 0, y: 0, width: side, height: side)), with: .color(Color(.systemBackground)))

        // Highlights: the selected cell, its row and column, and matching digits.
        if let sel = session.selected {
            let digit = session.entries[sel]
            for c in 0..<session.cellCount {
                var fill: Color?
                if settings.highlightMatching && (c / n == sel / n || c % n == sel % n) { fill = Theme.related }
                if settings.highlightMatching && digit != 0 && session.entries[c] == digit { fill = Theme.sameDigit }
                if c == sel { fill = Theme.selected }
                if let fill { ctx.fill(Path(rect(c, unit)), with: .color(fill)) }
            }
        }
        for c in 0..<session.cellCount where session.color(of: c) != 0 {
            ctx.fill(Path(rect(c, unit)), with: .color(Theme.cellColors[session.color(of: c) - 1]))
        }
        for c in session.flaggedWrong { ctx.fill(Path(rect(c, unit)), with: .color(Theme.wrongFill)) }
        for c in spotlight { ctx.fill(Path(rect(c, unit)), with: .color(Color.yellow.opacity(0.35))) }

        // Digits and notes.
        let shown = session.displayedNotes()
        let grid = NoteGrid(killer: true)
        for c in 0..<session.cellCount {
            let r = rect(c, unit)
            let v = session.entries[c]
            if v != 0 {
                let wrong = settings.mistakeHighlighting && session.isWrong(c)
                let color = session.isGiven(c) ? Theme.given : (wrong ? Theme.wrong : Theme.entry)
                let text = Text("\(v)").font(.system(size: unit * 0.56, weight: session.isGiven(c) ? .semibold : .regular)).foregroundStyle(color)
                ctx.draw(text, at: CGPoint(x: r.midX, y: r.midY + unit * 0.07))
            } else {
                for d in shown[c].digits {
                    let center = grid.center(of: d)
                    let p = CGPoint(x: r.minX + unit * center.x, y: r.minY + unit * center.y)
                    let marked = marks.contains(CellDigit(cell: c, digit: d))
                    ctx.draw(Text("\(d)").font(.system(size: unit * grid.fontSize, weight: marked ? .bold : .regular))
                        .foregroundStyle(marked ? Theme.wrong : Theme.note), at: p)
                    if marked {
                        let w = unit * (1 - 2 * grid.side) / 3
                        var strike = Path()
                        strike.move(to: CGPoint(x: p.x - w * 0.35, y: p.y + w * 0.3))
                        strike.addLine(to: CGPoint(x: p.x + w * 0.35, y: p.y - w * 0.3))
                        ctx.stroke(strike, with: .color(Theme.wrong), lineWidth: 1.2)
                    }
                }
            }
        }

        // Thin lines between every cell, thick lines where cages meet and around the outside.
        let cage = session.puzzle.cageIndex
        var thin = Path(), thick = Path()
        for r in 0..<n {
            for c in 0..<n {
                let cell = r * n + c
                let x = CGFloat(c + 1) * unit, y = CGFloat(r + 1) * unit
                if c < n - 1 {
                    var p = Path(); p.move(to: CGPoint(x: x, y: CGFloat(r) * unit)); p.addLine(to: CGPoint(x: x, y: y))
                    if cage[cell] != cage[cell + 1] { thick.addPath(p) } else { thin.addPath(p) }
                }
                if r < n - 1 {
                    var p = Path(); p.move(to: CGPoint(x: CGFloat(c) * unit, y: y)); p.addLine(to: CGPoint(x: x, y: y))
                    if cage[cell] != cage[cell + n] { thick.addPath(p) } else { thin.addPath(p) }
                }
            }
        }
        ctx.stroke(thin, with: .color(.primary.opacity(0.25)), lineWidth: 0.5)
        ctx.stroke(thick, with: .color(.primary.opacity(0.9)), style: StrokeStyle(lineWidth: 2, lineCap: .round))
        ctx.stroke(Path(CGRect(x: 1, y: 1, width: side - 2, height: side - 2)), with: .color(.primary.opacity(0.9)), lineWidth: 2.5)

        // Clues in each cage's top-left cell.
        for cage in session.puzzle.cages where cage.op != .given {
            guard let anchor = cage.cells.min() else { continue }
            let r = rect(anchor, unit)
            let text = Text(cage.label).font(.system(size: unit * 0.21, weight: .semibold, design: .rounded)).foregroundStyle(.primary)
            ctx.draw(text, at: CGPoint(x: r.minX + unit * 0.07, y: r.minY + unit * 0.05), anchor: .topLeading)
        }
    }
}
