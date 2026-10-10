import Foundation
import SudokuCore

struct Options {
    var mode = Mode.classic
    var tier: Tier?
    var count = 10
    var out: String?
    var seed: UInt64?
    var timeout = 60.0
}

func log(_ message: String) {
    FileHandle.standardError.write(Data((message + "\n").utf8))
}

func usage() -> Never {
    log("""
    usage: sudoku-forge --tier easy|medium|hard|expert|fiendish|diabolical|nightmare --out FILE
                        [--mode classic|killer] [--count N] [--seed N] [--timeout SECONDS]
    """)
    exit(2)
}

func parse(_ args: [String]) -> Options {
    var o = Options()
    var i = 0
    while i < args.count {
        guard i + 1 < args.count else { usage() }
        let value = args[i + 1]
        switch args[i] {
        case "--mode":
            guard let m = Mode(rawValue: value) else { usage() }
            o.mode = m
        case "--tier":
            guard let t = Tier(name: value) else { usage() }
            o.tier = t
        case "--count":
            guard let n = Int(value), n > 0 else { usage() }
            o.count = n
        case "--out":
            o.out = value
        case "--seed":
            guard let s = UInt64(value) else { usage() }
            o.seed = s
        case "--timeout":
            guard let t = Double(value), t > 0 else { usage() }
            o.timeout = t
        default:
            usage()
        }
        i += 2
    }
    guard o.tier != nil, o.out != nil else { usage() }
    return o
}

let options = parse(Array(CommandLine.arguments.dropFirst()))
let tier = options.tier!

guard options.mode == .classic else {
    log("killer generation is not implemented yet")
    exit(1)
}
guard tier <= LogicalSolver.classic.maxTier else {
    log("tier \(tier.name) is not supported yet (max: \(LogicalSolver.classic.maxTier.name))")
    exit(1)
}

var rng = SplitMix64(seed: options.seed ?? UInt64.random(in: .min ... .max))
let generator = ClassicGenerator()
var puzzles: [Puzzle] = []

while puzzles.count < options.count {
    let deadline = ContinuousClock.now + .seconds(options.timeout)
    guard let puzzle = generator.generate(tier: tier, using: &rng, deadline: deadline) else {
        log("timed out after \(options.timeout)s on puzzle \(puzzles.count + 1); writing \(puzzles.count)")
        break
    }
    puzzles.append(puzzle)
    let techniques = puzzle.techniquesRequired.map(\.rawValue).joined(separator: ",")
    log("[\(puzzles.count)/\(options.count)] score \(puzzle.grade.score) \(techniques)")
}

let encoder = JSONEncoder()
encoder.outputFormatting = [.sortedKeys]
do {
    try encoder.encode(puzzles).write(to: URL(fileURLWithPath: options.out!))
} catch {
    log("failed to write \(options.out!): \(error)")
    exit(1)
}
