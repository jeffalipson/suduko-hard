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
