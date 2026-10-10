/// A human solving technique. `find` returns the first instance on the board
/// that makes progress (at least one placement or elimination), or nil.
public protocol Technique: Sendable {
    var id: TechniqueID { get }
    func find(in board: Board) -> Step?
}
