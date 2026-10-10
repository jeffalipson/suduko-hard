// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SudokuCore",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "SudokuCore", targets: ["SudokuCore"]),
        .library(name: "SudokuGame", targets: ["SudokuGame"]),
        .executable(name: "sudoku-forge", targets: ["sudoku-forge"]),
    ],
    targets: [
        .target(name: "SudokuCore"),
        .target(name: "SudokuGame", dependencies: ["SudokuCore"]),
        .executableTarget(name: "sudoku-forge", dependencies: ["SudokuCore"]),
        .testTarget(name: "SudokuCoreTests", dependencies: ["SudokuCore"]),
        .testTarget(name: "SudokuGameTests", dependencies: ["SudokuGame", "SudokuCore"]),
    ]
)
