import SwiftUI

@main
struct HardSudokuApp: App {
    @State private var model = AppModel()
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
