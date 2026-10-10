/// Static board geometry. Cells are 0..<81, row-major.
public enum Geometry {
    public static func row(_ cell: Int) -> Int { cell / 9 }
    public static func col(_ cell: Int) -> Int { cell % 9 }
    public static func box(_ cell: Int) -> Int { (cell / 27) * 3 + (cell % 9) / 3 }
    public static func cell(_ row: Int, _ col: Int) -> Int { row * 9 + col }

    public static let rows: [[Int]] = (0..<9).map { r in (0..<9).map { r * 9 + $0 } }
    public static let cols: [[Int]] = (0..<9).map { c in (0..<9).map { $0 * 9 + c } }
    public static let boxes: [[Int]] = (0..<9).map { b in
        let r0 = (b / 3) * 3, c0 = (b % 3) * 3
        return (0..<9).map { (r0 + $0 / 3) * 9 + c0 + $0 % 3 }
    }

    /// All 27 houses: indices 0–8 are rows, 9–17 columns, 18–26 boxes.
    public static let houses: [[Int]] = rows + cols + boxes

    public static let peers: [[Int]] = (0..<81).map { c in
        Set(rows[row(c)] + cols[col(c)] + boxes[box(c)]).subtracting([c]).sorted()
    }

    /// True when two different cells share a row, column or box.
    public static func sees(_ a: Int, _ b: Int) -> Bool {
        a != b && (row(a) == row(b) || col(a) == col(b) || box(a) == box(b))
    }
}

public enum Region: Hashable, Sendable, Codable {
    case row(Int)
    case column(Int)
    case box(Int)

    /// Maps a `Geometry.houses` index to its region.
    public init(house: Int) {
        switch house {
        case 0..<9: self = .row(house)
        case 9..<18: self = .column(house - 9)
        default: self = .box(house - 18)
        }
    }

    public var cells: [Int] {
        switch self {
        case .row(let i): return Geometry.rows[i]
        case .column(let i): return Geometry.cols[i]
        case .box(let i): return Geometry.boxes[i]
        }
    }
}
