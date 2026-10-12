import SwiftUI
import SudokuGame

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
                .preferredColorScheme(model.settings.appearance.colorScheme)
                .modelContainer(model.container)
                .task { await model.refillLoop() }
        }
        .onChange(of: phase) { _, new in
            if new == .background { model.save(); model.scheduleBackgroundRefill() }
            if new == .active { Task { await model.refillLoop() } }
        }
    }
}

extension Appearance {
    /// nil follows the system setting.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}
