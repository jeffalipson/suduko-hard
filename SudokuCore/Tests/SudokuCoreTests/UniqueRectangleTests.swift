import Testing
import SudokuCore

@Suite struct UniqueRectangleTests {
    func rectangle(roof1: [Int], roof2: [Int]) -> Board {
        var b = emptyBoard()
        b.candidates[rc(0, 0)] = CandidateSet([1, 2])
        b.candidates[rc(1, 0)] = CandidateSet([1, 2])
        b.candidates[rc(0, 3)] = CandidateSet(roof1)
        b.candidates[rc(1, 3)] = CandidateSet(roof2)
        return b
    }

    @Test func type1() throws {
        let b = rectangle(roof1: [1, 2], roof2: [1, 2, 5, 7])
        let step = try #require(UniqueRectangle(type: 1).find(in: b))
        #expect(step.technique == .uniqueRectangle1)
        #expect(Set(step.eliminations) == [CellDigit(cell: rc(1, 3), digit: 1), CellDigit(cell: rc(1, 3), digit: 2)])
        #expect(step.digits == [1, 2])
    }

    @Test func type2() throws {
        let b = rectangle(roof1: [1, 2, 6], roof2: [1, 2, 6])
        let step = try #require(UniqueRectangle(type: 2).find(in: b))
        #expect(step.technique == .uniqueRectangle2)
        #expect(step.eliminations.count == 13)   // rest of column 3 (7) + rest of box 1 off column 3 (6)
        #expect(step.eliminations.allSatisfy { $0.digit == 6 })
    }

    @Test func type3() throws {
        var b = rectangle(roof1: [1, 2, 3], roof2: [1, 2, 4])
        b.candidates[rc(5, 3)] = CandidateSet([3, 4])
        let step = try #require(UniqueRectangle(type: 3).find(in: b))
        #expect(step.technique == .uniqueRectangle3)
        let others = [2, 3, 4, 6, 7, 8].map { rc($0, 3) }
        #expect(Set(step.eliminations) == Set(others.flatMap { [CellDigit(cell: $0, digit: 3), CellDigit(cell: $0, digit: 4)] }))
    }

    @Test func type4() throws {
        var b = rectangle(roof1: [1, 2, 6, 7], roof2: [1, 2, 6, 7])
        for row in 2..<9 { b.eliminate(1, at: rc(row, 3)) }   // 1 only in the roof within column 3
        let step = try #require(UniqueRectangle(type: 4).find(in: b))
        #expect(step.technique == .uniqueRectangle4)
        #expect(Set(step.eliminations) == [CellDigit(cell: rc(0, 3), digit: 2), CellDigit(cell: rc(1, 3), digit: 2)])
    }

    @Test func solvedCornerIsNotARectangle() {
        var b = rectangle(roof1: [1, 2], roof2: [1, 2, 5, 7])
        b.place(1, at: rc(0, 3))
        #expect(UniqueRectangle(type: 1).find(in: b) == nil)
    }

    @Test(arguments: 1...4)
    func sound(type: Int) {
        #expect(soundnessViolations(of: UniqueRectangle(type: type), seeds: 1...30).isEmpty)
    }
}
