import SwiftUI

@main
struct HardSudokuApp: App {
    @State private var model: AppModel

    init() {
        // UI tests start from a clean slate every launch.
        if AppModel.isUITest { try? FileManager.default.removeItem(at: Persistence.url) }
        _model = State(initialValue: AppModel())
    }
    @Environment(\.scenePhase) private var phase

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(model)
                .modelContainer(model.container)
                .task { await model.refillLoop() }
        }
        .onChange(of: phase) { _, new in
            if new == .background { model.save(); model.scheduleBackgroundRefill() }
            if new == .active { Task { await model.refillLoop() } }
        }
    }
}
