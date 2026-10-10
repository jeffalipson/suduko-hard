/// Two parallel strong links on a digit whose bases share a cross line:
/// one of the two roofs holds the digit, so cells seeing both roofs lose it.
public struct Skyscraper: Technique {
    public init() {}
    public var id: TechniqueID { .skyscraper }

    public func find(in board: Board) -> Step? {
        for digit in 1...9 {
            for lines in [0..<9, 9..<18] {
                let rowsAreLines = lines.lowerBound == 0
                func cross(_ cell: Int) -> Int { rowsAreLines ? Geometry.col(cell) : Geometry.row(cell) }
                for links in board.conjugatePairs(of: digit, houses: lines).combinations(of: 2) {
                    let (p, q) = (links[0], links[1])
                    for (base1, roof1) in p.ends {
                        for (base2, roof2) in q.ends {
                            guard cross(base1) == cross(base2), cross(roof1) != cross(roof2) else { continue }
                            let pattern = [base1, roof1, base2, roof2]
                            let eliminations = board.eliminations(of: digit, seeingAll: [roof1, roof2], excluding: pattern)
                            guard !eliminations.isEmpty else { continue }
                            return Step(
                                technique: id,
                                patternCells: pattern,
                                patternCandidates: pattern.map { CellDigit(cell: $0, digit: digit) },
                                eliminations: eliminations,
                                regions: [Region(house: p.house), Region(house: q.house)],
                                digits: [digit]
                            )
                        }
                    }
                }
            }
        }
        return nil
    }
}

/// A row strong link and a column strong link with one end each in the same box:
/// one of the two far ends holds the digit.
public struct TwoStringKite: Technique {
    public init() {}
    public var id: TechniqueID { .twoStringKite }

    public func find(in board: Board) -> Step? {
        for digit in 1...9 {
            let rowLinks = board.conjugatePairs(of: digit, houses: 0..<9)
            let colLinks = board.conjugatePairs(of: digit, houses: 9..<18)
            for rowLink in rowLinks {
                for colLink in colLinks {
                    for (rowEnd, rowOther) in rowLink.ends {
                        for (colEnd, colOther) in colLink.ends {
                            let pattern = [rowOther, rowEnd, colEnd, colOther]
                            guard Set(pattern).count == 4, Geometry.box(rowEnd) == Geometry.box(colEnd) else { continue }
                            let eliminations = board.eliminations(of: digit, seeingAll: [rowOther, colOther], excluding: pattern)
                            guard !eliminations.isEmpty else { continue }
                            return Step(
                                technique: id,
                                patternCells: pattern,
                                patternCandidates: pattern.map { CellDigit(cell: $0, digit: digit) },
                                eliminations: eliminations,
                                regions: [Region(house: rowLink.house), Region(house: colLink.house), .box(Geometry.box(rowEnd))],
                                digits: [digit]
                            )
                        }
                    }
                }
            }
        }
        return nil
    }
}

/// A box whose candidates for a digit lie on one row and one column (a cross), combined with
/// a strong link that ends on the cross's row or column outside the box.
public struct EmptyRectangle: Technique {
    public init() {}
    public var id: TechniqueID { .emptyRectangle }

    public func find(in board: Board) -> Step? {
        for digit in 1...9 {
            for b in 0..<9 {
                let boxCells = board.cells(with: digit, in: Geometry.boxes[b])
                guard boxCells.count >= 2 else { continue }
                let boxRows = Set(Geometry.boxes[b].map(Geometry.row))
                let boxCols = Set(Geometry.boxes[b].map(Geometry.col))
                for r in boxRows.sorted() {
                    for c in boxCols.sorted() {
                        guard boxCells.allSatisfy({ Geometry.row($0) == r || Geometry.col($0) == c }),
                              boxCells.contains(where: { Geometry.row($0) == r && Geometry.col($0) != c }),
                              boxCells.contains(where: { Geometry.col($0) == c && Geometry.row($0) != r })
                        else { continue }

                        func step(link: ConjugatePair, end: Int, other: Int, target: Int) -> Step {
                            Step(
                                technique: id,
                                patternCells: boxCells + [end, other],
                                patternCandidates: (boxCells + [end, other]).map { CellDigit(cell: $0, digit: digit) },
                                eliminations: [CellDigit(cell: target, digit: digit)],
                                regions: [.box(b), Region(house: link.house)],
                                digits: [digit]
                            )
                        }

                        // Strong link in a column outside the box, one end on row r.
                        for link in board.conjugatePairs(of: digit, houses: 9..<18) where !boxCols.contains(link.house - 9) {
                            for (end, other) in link.ends where Geometry.row(end) == r && !boxRows.contains(Geometry.row(other)) {
                                let target = Geometry.cell(Geometry.row(other), c)
                                if board.has(digit, at: target) { return step(link: link, end: end, other: other, target: target) }
                            }
                        }
                        // Strong link in a row outside the box, one end on column c.
                        for link in board.conjugatePairs(of: digit, houses: 0..<9) where !boxRows.contains(link.house) {
                            for (end, other) in link.ends where Geometry.col(end) == c && !boxCols.contains(Geometry.col(other)) {
                                let target = Geometry.cell(r, Geometry.col(other))
                                if board.has(digit, at: target) { return step(link: link, end: end, other: other, target: target) }
                            }
                        }
                    }
                }
            }
        }
        return nil
    }
}
