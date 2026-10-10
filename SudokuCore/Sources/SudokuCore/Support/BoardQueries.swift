/// Two cells that are the only places for a digit in a house (a strong link).
struct ConjugatePair {
    let house: Int
    let a: Int
    let b: Int

    /// Both orientations as (end, other end).
    var ends: [(Int, Int)] { [(a, b), (b, a)] }
}

extension Board {
    /// True when `cell` is empty and still has `digit` as a candidate.
    func has(_ digit: Int, at cell: Int) -> Bool {
        values[cell] == 0 && candidates[cell].contains(digit)
    }

    /// Cells of `house` that still hold `digit`.
    func cells(with digit: Int, in house: [Int]) -> [Int] {
        house.filter { has(digit, at: $0) }
    }

    /// Removes `digit` from every cell that sees all of `targets`,
    /// skipping the targets themselves and any `pattern` cells.
    func eliminations(of digit: Int, seeingAll targets: [Int], excluding pattern: [Int] = []) -> [CellDigit] {
        (0..<81)
            .filter { c in
                has(digit, at: c) && !targets.contains(c) && !pattern.contains(c)
                    && targets.allSatisfy { Geometry.sees($0, c) }
            }
            .map { CellDigit(cell: $0, digit: digit) }
    }

    /// Strong links for `digit` in the given houses.
    func conjugatePairs(of digit: Int, houses: Range<Int> = 0..<27) -> [ConjugatePair] {
        houses.compactMap { h in
            let found = cells(with: digit, in: Geometry.houses[h])
            return found.count == 2 ? ConjugatePair(house: h, a: found[0], b: found[1]) : nil
        }
    }

    /// Every candidate of the given cells, for `Step.patternCandidates`.
    func candidateDigits(of cells: [Int]) -> [CellDigit] {
        cells.flatMap { c in candidates[c].digits.map { CellDigit(cell: c, digit: $0) } }
    }
}
