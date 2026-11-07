import Testing
@testable import SudokuCore

@Suite struct PrimeFactorTests {
    @Test func factorsWithPowers() {
        #expect(MathCage.primeFactors(72).map { [$0.prime, $0.power] } == [[2, 3], [3, 2]])
        #expect(MathCage.primeFactors(1120).map { [$0.prime, $0.power] } == [[2, 5], [5, 1], [7, 1]])
        #expect(MathCage.primeFactors(7).map { [$0.prime, $0.power] } == [[7, 1]])
        #expect(MathCage.primeFactors(1).isEmpty)
    }

    @Test func readableText() {
        #expect(MathCage.factorText(72) == "2³ · 3²")
        #expect(MathCage.factorText(1120) == "2⁵ · 5 · 7")
        #expect(MathCage.factorText(13) == "13")
        #expect(MathCage.factorText(1) == "1")
        #expect(MathCage.factorText(1024) == "2¹⁰")
    }

    @Test func onlyMultiplyAndHiddenCagesShowFactors() {
        #expect(MathCage(cells: [0, 1], op: .multiply, target: 12).showsFactors)
        #expect(MathCage(cells: [0, 1], op: .hidden, target: 12).showsFactors)
        #expect(!MathCage(cells: [0, 1], op: .add, target: 12).showsFactors)
        #expect(!MathCage(cells: [0], op: .given, target: 3).showsFactors)
    }
}
