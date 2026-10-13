/// A hardware-keyboard key, reduced to what the game cares about.
public enum GameKey: Equatable, Sendable {
    case up, down, left, right, delete
    /// The characters the key produced (digits, space, …).
    case text(String)
}

public enum GameKeyAction: Equatable, Sendable {
    case move(rows: Int, columns: Int)
    case digit(Int)
    case erase
    case toggleInputMode
}

public enum KeyCommand {
    public static func action(for key: GameKey) -> GameKeyAction? {
        switch key {
        case .up: return .move(rows: -1, columns: 0)
        case .down: return .move(rows: 1, columns: 0)
        case .left: return .move(rows: 0, columns: -1)
        case .right: return .move(rows: 0, columns: 1)
        case .delete: return .erase
        case .text(let t):
            if t == " " { return .toggleInputMode }
            if t == "\u{7F}" || t == "\u{8}" { return .erase }
            if t.count == 1, let d = Int(t), (1...9).contains(d) { return .digit(d) }
            return nil
        }
    }
}
