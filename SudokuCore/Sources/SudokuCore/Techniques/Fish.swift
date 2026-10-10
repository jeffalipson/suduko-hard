/// A choice of base lines (all rows or all columns) for a fish on one digit.
struct FishBase {
    let baseHouses: [Int]
    /// The digit's candidate cells inside the base lines.
    let cells: [Int]
    let baseIsRows: Bool

    /// Cover-line index (0–8) of a cell: its column when the base lines are rows.
    func coverIndex(_ cell: Int) -> Int { baseIsRows ? Geometry.col(cell) : Geometry.row(cell) }

    var coverIndices: [Int] { Set(cells.map(coverIndex)).sorted() }

    func coverHouse(_ index: Int) -> Int { baseIsRows ? 9 + index : index }

    /// Every `size`-combination of base lines holding 2...`maxPerLine` candidates of `digit`.
    static func all(board: Board, digit: Int, baseIsRows: Bool, size: Int, maxPerLine: Int) -> [FishBase] {
        let lines = baseIsRows ? Array(0..<9) : Array(9..<18)
        let eligible = lines.filter {
            (2...maxPerLine).contains(board.cells(with: digit, in: Geometry.houses[$0]).count)
        }
        return eligible.combinations(of: size).map { combo in
            FishBase(
                baseHouses: combo,
                cells: combo.flatMap { board.cells(with: digit, in: Geometry.houses[$0]) },
                baseIsRows: baseIsRows
            )
        }
    }
}

/// N base lines whose candidates for a digit lie in exactly N cover lines: the digit leaves
/// the rest of the cover lines. X-Wing (2), Swordfish (3), Jellyfish (4).
public struct BasicFish: Technique {
    public let size: Int

    public init(size: Int) {
        precondition((2...4).contains(size), "Fish size must be 2, 3 or 4")
        self.size = size
    }

    public var id: TechniqueID {
        switch size {
        case 2: return .xWing
        case 3: return .swordfish
        default: return .jellyfish
        }
    }

    public func find(in board: Board) -> Step? {
        for digit in 1...9 {
            for baseIsRows in [true, false] {
                for base in FishBase.all(board: board, digit: digit, baseIsRows: baseIsRows, size: size, maxPerLine: size) {
                    let cover = base.coverIndices
                    guard cover.count == size else { continue }
                    let coverHouses = cover.map(base.coverHouse)
                    let eliminations = coverHouses
                        .flatMap { Geometry.houses[$0] }
                        .filter { board.has(digit, at: $0) && !base.cells.contains($0) }
                        .map { CellDigit(cell: $0, digit: digit) }
                    guard !eliminations.isEmpty else { continue }
                    return Step(
                        technique: id,
                        patternCells: base.cells,
                        patternCandidates: base.cells.map { CellDigit(cell: $0, digit: digit) },
                        eliminations: eliminations,
                        regions: (base.baseHouses + coverHouses).map(Region.init(house:)),
                        digits: [digit]
                    )
                }
            }
        }
        return nil
    }
}

/// A fish with extra candidates ("fins") confined to one box: either a fin is true or the
/// fish holds, so cover-line cells inside the fin box lose the digit.
public struct FinnedFish: Technique {
    public let size: Int

    public init(size: Int) {
        precondition((2...3).contains(size), "Finned fish size must be 2 or 3")
        self.size = size
    }

    public var id: TechniqueID { size == 2 ? .finnedXWing : .finnedSwordfish }

    public func find(in board: Board) -> Step? {
        for digit in 1...9 {
            for baseIsRows in [true, false] {
                for base in FishBase.all(board: board, digit: digit, baseIsRows: baseIsRows, size: size, maxPerLine: size + 2) {
                    let allCover = base.coverIndices
                    guard allCover.count > size else { continue }
                    for cover in allCover.combinations(of: size) {
                        let fins = base.cells.filter { !cover.contains(base.coverIndex($0)) }
                        let finBox = Geometry.box(fins[0])
                        guard fins.allSatisfy({ Geometry.box($0) == finBox }) else { continue }
                        // Every base line keeps at least one candidate inside the cover.
                        let covered = base.baseHouses.allSatisfy { h in
                            Geometry.houses[h].contains { base.cells.contains($0) && cover.contains(base.coverIndex($0)) }
                        }
                        guard covered else { continue }
                        let eliminations = cover.map(base.coverHouse)
                            .flatMap { Geometry.houses[$0] }
                            .filter { board.has(digit, at: $0) && !base.cells.contains($0) && Geometry.box($0) == finBox }
                            .map { CellDigit(cell: $0, digit: digit) }
                        guard !eliminations.isEmpty else { continue }
                        return Step(
                            technique: id,
                            patternCells: base.cells,
                            patternCandidates: base.cells.map { CellDigit(cell: $0, digit: digit) },
                            eliminations: eliminations,
                            regions: (base.baseHouses + cover.map(base.coverHouse)).map(Region.init(house:)) + [.box(finBox)],
                            digits: [digit]
                        )
                    }
                }
            }
        }
        return nil
    }
}
