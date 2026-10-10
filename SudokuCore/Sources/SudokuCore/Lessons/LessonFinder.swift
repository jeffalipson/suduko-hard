public enum LessonFinder {
    public static func technique(for id: TechniqueID) -> (any Technique)? {
        (TechniqueCatalog.classic + TechniqueCatalog.killer).first { $0.id == id }
    }

    /// A solve-path state where `id` is the solver's next step (so the lesson shows it in context),
    /// falling back to the first state where `id` merely applies.
    public static func find(_ id: TechniqueID, seeds: Range<UInt64>) -> LessonExample? {
        search(id, seeds: seeds, requireNext: true) ?? search(id, seeds: seeds, requireNext: false)
    }

    static func search(_ id: TechniqueID, seeds: Range<UInt64>, requireNext: Bool) -> LessonExample? {
        guard let technique = technique(for: id) else { return nil }
        let killer = id.isKillerOnly
        let solver = killer ? LogicalSolver.killer : LogicalSolver.classic
        for seed in seeds {
            var rng = SplitMix64(seed: seed)
            let solution = BruteForceSolver.randomSolution(using: &rng)
            var givens = solution
            var cages: [Cage] = []
            if killer {
                cages = KillerCages.partition(solution: solution, sizes: 2...5, using: &rng)
                givens = Array(repeating: 0, count: 81)
            } else {
                for c in Array(0..<81).shuffled(using: &rng) {
                    let saved = givens[c]
                    givens[c] = 0
                    if BruteForceSolver.countSolutions(givens) != 1 { givens[c] = saved }
                }
            }
            var board = Board(values: givens, cages: cages)
            for _ in 0..<400 {
                let next = solver.nextStep(on: board)
                if requireNext {
                    if let next, next.technique == id { return LessonExample(technique: id, board: board, step: next) }
                } else if let step = technique.find(in: board) {
                    return LessonExample(technique: id, board: board, step: step)
                }
                guard let next else { break }
                board.apply(next)
            }
        }
        return nil
    }
}
