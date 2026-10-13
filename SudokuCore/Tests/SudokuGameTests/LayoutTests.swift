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

    @Test func splitViewsStackWhenThatGivesTheBiggerBoard() {
        #expect(GameLayout.choose(width: 440, height: 960) == .stacked)
        #expect(GameLayout.choose(width: 688, height: 960) == .stacked)
        // Square ⅔ window: stacked board min(944, 660) = 660 beats side-by-side 572.
        #expect(GameLayout.choose(width: 960, height: 960) == .stacked)
    }

    @Test func shortWideWindowGoesSideBySide() {
        // Stacked would leave a tiny board (height − 300); beside the controls it stays big.
        #expect(GameLayout.choose(width: 1000, height: 390) == .sideBySide(board: 358))
        #expect(GameLayout.choose(width: 1000, height: 500) == .sideBySide(board: 468))
        #expect(GameLayout.choose(width: 1000, height: 600) == .sideBySide(board: 568))
    }

    @Test func picksTheBiggerBoardNearTheSwitchPoint() {
        // stacked min(1084, 500) = 500 vs side-by-side min(768, 712) = 712
        #expect(GameLayout.choose(width: 1100, height: 800) == .sideBySide(board: 712))
        // stacked min(884, 600) = 600 vs side-by-side min(868, 512) = 512
        #expect(GameLayout.choose(width: 900, height: 900) == .stacked)
    }

    @Test func quarterTiledWindowsGoSideBySide() {
        // iPad 11" quarter tile: stacked would leave min(589, 50) = 50; beside the column it's 217.
        #expect(GameLayout.choose(width: 605, height: 350) == .sideBySide(board: 217))
        // iPad mini quarter tile: stacked 10 vs side-by-side 178.
        #expect(GameLayout.choose(width: 566, height: 310) == .sideBySide(board: 178))
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
