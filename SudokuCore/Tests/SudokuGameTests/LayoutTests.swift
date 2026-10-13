import Testing
import SudokuGame

@Suite struct LayoutTests {
    @Test func phonesStack() {
        #expect(GameLayout.choose(width: 375, height: 600) == .stacked)
        #expect(GameLayout.choose(width: 402, height: 780) == .stacked)
    }

    @Test func portraitIPadsStack() {
        #expect(GameLayout.choose(width: 744, height: 1080) == .stacked)
        #expect(GameLayout.choose(width: 834, height: 1150) == .stacked)
        #expect(GameLayout.choose(width: 1032, height: 1310) == .stacked)
    }

    @Test func landscapeIPadsGoSideBySide() {
        #expect(GameLayout.choose(width: 1133, height: 690) == .sideBySide(board: 658))
        #expect(GameLayout.choose(width: 1210, height: 780) == .sideBySide(board: 748))
        #expect(GameLayout.choose(width: 1376, height: 960) == .sideBySide(board: 928))
    }

    @Test func splitViewThirdsStackAndTwoThirdsGoSideBySide() {
        #expect(GameLayout.choose(width: 440, height: 960) == .stacked)
        #expect(GameLayout.choose(width: 688, height: 960) == .stacked)
        #expect(GameLayout.choose(width: 960, height: 960) == .sideBySide(board: 572))
    }

    @Test func shortWideWindowStacks() {
        #expect(GameLayout.choose(width: 1000, height: 500) == .stacked)
        #expect(GameLayout.choose(width: 1000, height: 599) == .stacked)
        #expect(GameLayout.choose(width: 1000, height: 600) == .sideBySide(board: 568))
    }

    @Test func boardBelowMinimumStacks() {
        // width − 388 = 359 < 360
        #expect(GameLayout.choose(width: 747, height: 700) == .stacked)
        #expect(GameLayout.choose(width: 748, height: 700) == .sideBySide(board: 360))
    }

    @Test func homeColumns() {
        #expect(HomeLayout.choose(width: 402, height: 874) == .singleColumn)
        #expect(HomeLayout.choose(width: 834, height: 1210) == .singleColumn)
        #expect(HomeLayout.choose(width: 688, height: 1024) == .singleColumn)
        #expect(HomeLayout.choose(width: 899, height: 700) == .singleColumn)
        #expect(HomeLayout.choose(width: 900, height: 700) == .twoColumns)
        #expect(HomeLayout.choose(width: 1210, height: 834) == .twoColumns)
        #expect(HomeLayout.choose(width: 1000, height: 1000) == .singleColumn)   // not wider than tall
    }
}
