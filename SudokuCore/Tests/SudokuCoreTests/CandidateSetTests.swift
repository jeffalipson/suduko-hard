import Testing
import SudokuCore

@Suite struct CandidateSetTests {
    @Test func insertRemoveContains() {
        var s = CandidateSet.empty
        s.insert(3)
        s.insert(9)
        #expect(s.contains(3))
        #expect(s.contains(9))
        #expect(!s.contains(1))
        #expect(s.count == 2)
        s.remove(3)
        #expect(s.digits == [9])
        #expect(s.single == 9)
    }

    @Test func allHasNineDigits() {
        #expect(CandidateSet.all.digits == Array(1...9))
        #expect(CandidateSet.all.single == nil)
        #expect(CandidateSet.empty.isEmpty)
    }

    @Test func setAlgebra() {
        let a = CandidateSet([1, 2, 3])
        let b = CandidateSet([2, 3, 4])
        #expect(a.union(b).digits == [1, 2, 3, 4])
        #expect(a.intersection(b).digits == [2, 3])
        #expect(a.subtracting(b).digits == [1])
    }

    @Test func rawInitIgnoresBitsOutsideOneToNine() {
        #expect(CandidateSet(raw: 0xFFFF).digits == Array(1...9))
    }
}
