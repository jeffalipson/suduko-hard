import SudokuCore

/// Wikipedia's example puzzle; solvable with singles only.
let wikiPuzzle = "530070000600195000098000060800060003400803001700020006060000280000419005000080079"
let wikiSolution = "534678912672195348198342567859761423426853791713924856961537284287419635345286179"
/// Arto Inkala's "world's hardest sudoku"; unique, needs far more than Hard-tier techniques.
let inkalaPuzzle = "800000000003600000070090200050007000000045700000100030001000068008500010090000400"

func emptyBoard() -> Board { Board(values: Array(repeating: 0, count: 81)) }

func values(_ s: String) -> [Int] { Board.parse(s)! }

func isValidSolution(_ v: [Int]) -> Bool {
    v.count == 81 && Geometry.houses.allSatisfy { house in Set(house.map { v[$0] }) == Set(1...9) }
}

func rc(_ row: Int, _ col: Int) -> Int { Geometry.cell(row, col) }

/// An all-candidates board where `digit` survives only in `cells`.
func board(digit: Int, onlyIn cells: [Int]) -> Board {
    var b = emptyBoard()
    for c in 0..<81 where !cells.contains(c) { b.eliminate(digit, at: c) }
    return b
}

/// A random unique puzzle: symmetric clue removal while the solution stays unique (no grading).
func randomUniquePuzzle(seed: UInt64) -> (givens: [Int], solution: [Int]) {
    var rng = SplitMix64(seed: seed)
    let solution = BruteForceSolver.randomSolution(using: &rng)
    var givens = solution
    var order = Array(0...40)
    order.shuffle(using: &rng)
    for c in order {
        let pair = c == 40 ? [40] : [c, 80 - c]
        let saved = pair.map { givens[$0] }
        for p in pair { givens[p] = 0 }
        if BruteForceSolver.countSolutions(givens) != 1 {
            for (p, v) in zip(pair, saved) { givens[p] = v }
        }
    }
    return (givens, solution)
}

/// True when a step never contradicts the known solution.
func isSound(_ step: Step, solution: [Int]) -> Bool {
    step.placements.allSatisfy { solution[$0.cell] == $0.digit }
        && step.eliminations.allSatisfy { solution[$0.cell] != $0.digit }
}

/// Walks the solve path of random unique puzzles (catalog + `technique`) and records every
/// unsound step `technique` produces along the way.
func soundnessViolations(of technique: any Technique, seeds: ClosedRange<Int>) -> [String] {
    let solver = LogicalSolver(techniques: TechniqueCatalog.classic + [technique])
    var failures: [String] = []
    for seed in seeds {
        let (givens, solution) = randomUniquePuzzle(seed: UInt64(seed))
        var board = Board(values: givens)
        for _ in 0..<500 {
            if let step = technique.find(in: board), !isSound(step, solution: solution) {
                failures.append("seed \(seed): \(step.technique) on \(board.string)")
            }
            guard let next = solver.nextStep(on: board) else { break }
            board.apply(next)
        }
    }
    return failures
}
