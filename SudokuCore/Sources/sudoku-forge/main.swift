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

if CommandLine.arguments.count == 3, CommandLine.arguments[1] == "--lessons" {
    var lessons: [LessonExample] = []
    for id in TechniqueID.allCases {
        if let lesson = LessonFinder.find(id, seeds: 1..<400) {
            lessons.append(lesson)
            log("lesson \(id.rawValue): found")
        } else {
            log("lesson \(id.rawValue): none")
        }
    }
    try JSONEncoder().encode(lessons).write(to: URL(fileURLWithPath: CommandLine.arguments[2]), options: .atomic)
    exit(0)
}

let options = parse(Array(CommandLine.arguments.dropFirst()))
let tier = options.tier!

let maxTier = options.mode == .classic ? LogicalSolver.classic.maxTier : LogicalSolver.killer.maxTier
guard tier <= maxTier else {
    log("tier \(tier.name) is not supported yet (max: \(maxTier.name))")
    exit(1)
}

var rng = SplitMix64(seed: options.seed ?? UInt64.random(in: .min ... .max))
@MainActor func generate(_ tier: Tier, _ deadline: ContinuousClock.Instant) -> Puzzle? {
    switch options.mode {
    case .classic: return ClassicGenerator().generate(tier: tier, using: &rng, deadline: deadline)
    case .killer: return KillerGenerator().generate(tier: tier, using: &rng, deadline: deadline)
    }
}
var puzzles: [Puzzle] = []

while puzzles.count < options.count {
    let deadline = ContinuousClock.now + .seconds(options.timeout)
    guard let puzzle = generate(tier, deadline) else {
        log("timed out after \(options.timeout)s on puzzle \(puzzles.count + 1); writing \(puzzles.count)")
        break
    }
    puzzles.append(puzzle)
    let techniques = puzzle.techniquesRequired.map(\.rawValue).joined(separator: ",")
    log("[\(puzzles.count)/\(options.count)] score \(puzzle.grade.score) \(techniques)")
}

// Never clobber an existing library with nothing.
guard !puzzles.isEmpty else {
    log("no puzzles generated; \(options.out!) left untouched")
    exit(3)
}

let encoder = JSONEncoder()
encoder.outputFormatting = [.sortedKeys]
do {
    try encoder.encode(puzzles).write(to: URL(fileURLWithPath: options.out!), options: .atomic)
} catch {
    log("failed to write \(options.out!): \(error)")
    exit(1)
}

// A short library is written, but the shortfall is reported to scripts.
if puzzles.count < options.count { exit(3) }
