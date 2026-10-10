import Foundation
import Testing
import SudokuCore
import SudokuGame

@Suite struct MinorFixTests {
    @Test func showMePlacementsClearPeerNotes() {
        var g = GameSession(puzzle: classicPuzzle())
        g.fillAllCandidates()
        guard case .step(let step) = HintEngine.diagnose(g), let p = step.placements.first else {
            Issue.record("expected a placing step"); return
        }
        g.showMe(step)
        for peer in Geometry.peers[p.cell] where g.entries[peer] == 0 {
            #expect(!g.notes[peer].contains(p.digit))
        }
    }

    @Test func revealClearsPeerNotesWhenAutoRemoveIsOn() {
        var g = GameSession(puzzle: classicPuzzle())
        g.fillAllCandidates()
        var s = GameSettings()
        s.autoRemoveCandidates = true
        g.selected = 2   // answer 4
        g.revealCell(settings: s)
        #expect(!g.notes[3].contains(4))
    }

    @Test func olderGamesKeepTheirMistakes() throws {
        // Saved before highlightingUsed existed.
        let log = try JSONDecoder().decode(AssistLog.self, from: Data(#"{"mistakes":2}"#.utf8))
        #expect(GameRecordData.recordedMistakes(log) == 2)
        #expect(GameRecordData.recordedMistakes(AssistLog()) == nil)
    }

    @Test func abandonRateTiesKeepTierOrder() {
        let records = [record(false, 1, day: 1, tier: .hard), record(false, 1, day: 2, tier: .easy)]
        #expect(StatsCalculator.abandonRates(records, mode: .classic).map(\.tier) == [.easy, .hard])
    }
}
