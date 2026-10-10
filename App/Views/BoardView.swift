import SwiftUI
import SudokuCore
import SudokuGame

/// The 9×9 grid: highlights, digits, notes, Killer cages and grid lines, drawn in one Canvas.
struct BoardView: View {
    let session: GameSession
    let settings: GameSettings
    /// Hint overlays: cells to spotlight, candidates forming the pattern (green), candidates removed (red).
    var spotlight: Set<Int> = []
    var marks: [CellDigit] = []
    var pattern: [CellDigit] = []
    /// Digits a hint places, drawn in green in their empty cells.
    var placed: [CellDigit] = []
    let onTap: (Int) -> Void

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            Canvas { ctx, _ in draw(in: &ctx, side: size) }
                .frame(width: size, height: size)
                .contentShape(Rectangle())
                .gesture(SpatialTapGesture().onEnded { tap in
                    let cell = size / 9
                    let r = min(8, max(0, Int(tap.location.y / cell)))
                    let c = min(8, max(0, Int(tap.location.x / cell)))
                    onTap(r * 9 + c)
                })
                .accessibilityIdentifier("board")
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func rect(_ cell: Int, _ unit: CGFloat) -> CGRect {
        CGRect(x: CGFloat(cell % 9) * unit, y: CGFloat(cell / 9) * unit, width: unit, height: unit)
    }

    private func draw(in ctx: inout GraphicsContext, side: CGFloat) {
        let unit = side / 9
        ctx.fill(Path(CGRect(x: 0, y: 0, width: side, height: side)), with: .color(Color(.systemBackground)))

        // Highlights.
        if let sel = session.selected {
            let digit = session.entries[sel]
            for c in 0..<81 {
                var fill: Color?
                if settings.highlightMatching && Geometry.sees(sel, c) { fill = Theme.related }
                if settings.highlightMatching && digit != 0 && session.entries[c] == digit { fill = Theme.sameDigit }
                if c == sel { fill = Theme.selected }
                if let fill { ctx.fill(Path(rect(c, unit)), with: .color(fill)) }
            }
        }
        for c in session.flaggedWrong { ctx.fill(Path(rect(c, unit)), with: .color(Theme.wrongFill)) }
        for c in spotlight { ctx.fill(Path(rect(c, unit)), with: .color(Color.yellow.opacity(0.35))) }

        // Cages.
        if !session.puzzle.cages.isEmpty { drawCages(in: &ctx, unit: unit) }

        // Digits and notes.
        for c in 0..<81 {
            let r = rect(c, unit)
            let v = session.entries[c]
            if v != 0 {
                let wrong = settings.mistakeHighlighting && session.isWrong(c)
                let color = session.isGiven(c) ? Theme.given : (wrong ? Theme.wrong : Theme.entry)
                let text = Text("\(v)").font(.system(size: unit * 0.58, weight: session.isGiven(c) ? .semibold : .regular)).foregroundStyle(color)
                ctx.draw(text, at: CGPoint(x: r.midX, y: r.midY + (session.puzzle.cages.isEmpty ? 0 : unit * 0.06)))
            } else if let p = placed.first(where: { $0.cell == c }) {
                let text = Text("\(p.digit)").font(.system(size: unit * 0.58, weight: .semibold)).foregroundStyle(Color.green)
                ctx.draw(text, at: CGPoint(x: r.midX, y: r.midY))
            } else {
                for d in session.notes[c].digits {
                    let col = CGFloat((d - 1) % 3), row = CGFloat((d - 1) / 3)
                    let inset = session.puzzle.cages.isEmpty ? unit * 0.06 : unit * 0.14
                    let w = (unit - 2 * inset) / 3
                    let p = CGPoint(x: r.minX + inset + w * (col + 0.5), y: r.minY + inset + w * (row + 0.5))
                    let cd = CellDigit(cell: c, digit: d)
                    let marked = marks.contains(cd)
                    let color = marked ? Theme.wrong : (pattern.contains(cd) ? Color.green : Theme.note)
                    ctx.draw(Text("\(d)").font(.system(size: unit * 0.22, weight: marked || pattern.contains(cd) ? .bold : .regular))
                        .foregroundStyle(color), at: p)
                    if marked {
                        var strike = Path()
                        strike.move(to: CGPoint(x: p.x - w * 0.35, y: p.y + w * 0.3))
                        strike.addLine(to: CGPoint(x: p.x + w * 0.35, y: p.y - w * 0.3))
                        ctx.stroke(strike, with: .color(Theme.wrong), lineWidth: 1.2)
                    }
                }
            }
        }

        // Grid lines.
        for i in 0...9 {
            let x = CGFloat(i) * unit
            let width: CGFloat = i % 3 == 0 ? 2 : 0.5
            var v = Path(); v.move(to: CGPoint(x: x, y: 0)); v.addLine(to: CGPoint(x: x, y: side))
            var h = Path(); h.move(to: CGPoint(x: 0, y: x)); h.addLine(to: CGPoint(x: side, y: x))
            ctx.stroke(v, with: .color(.primary.opacity(i % 3 == 0 ? 0.9 : 0.35)), lineWidth: width)
            ctx.stroke(h, with: .color(.primary.opacity(i % 3 == 0 ? 0.9 : 0.35)), lineWidth: width)
        }
    }

    private func drawCages(in ctx: inout GraphicsContext, unit: CGFloat) {
        let inset = unit * 0.08
        let style = StrokeStyle(lineWidth: 1, dash: [3, 2.5])
        for (i, cage) in session.puzzle.cages.enumerated() {
            let members = Set(cage.cells)
            var path = Path()
            for c in cage.cells {
                let r = rect(c, unit)
                let up = c >= 9 && members.contains(c - 9)
                let down = c < 72 && members.contains(c + 9)
                let left = c % 9 > 0 && members.contains(c - 1)
                let right = c % 9 < 8 && members.contains(c + 1)
                let x0 = left ? r.minX : r.minX + inset, x1 = right ? r.maxX : r.maxX - inset
                let y0 = up ? r.minY : r.minY + inset, y1 = down ? r.maxY : r.maxY - inset
                if !up { path.move(to: CGPoint(x: x0, y: r.minY + inset)); path.addLine(to: CGPoint(x: x1, y: r.minY + inset)) }
                if !down { path.move(to: CGPoint(x: x0, y: r.maxY - inset)); path.addLine(to: CGPoint(x: x1, y: r.maxY - inset)) }
                if !left { path.move(to: CGPoint(x: r.minX + inset, y: y0)); path.addLine(to: CGPoint(x: r.minX + inset, y: y1)) }
                if !right { path.move(to: CGPoint(x: r.maxX - inset, y: y0)); path.addLine(to: CGPoint(x: r.maxX - inset, y: y1)) }
            }
            ctx.stroke(path, with: .color(Theme.cage), style: style)
            let anchor = rect(cage.cells.min()!, unit)
            var label = "\(cage.sum)"
            if settings.remainingSum {
                let left = session.remainingSum(ofCage: i)
                if left != cage.sum { label += "·\(left)" }
            }
            let text = Text(label).font(.system(size: unit * 0.2, weight: .semibold)).foregroundStyle(.primary)
            ctx.draw(text, at: CGPoint(x: anchor.minX + inset + 1, y: anchor.minY + inset + 1), anchor: .topLeading)
        }
    }
}
