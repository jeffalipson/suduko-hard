import SwiftUI
import SudokuGame

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            Form {
                Section("Assists (using them counts against a clean solve)") {
                    Toggle("Auto-candidates button", isOn: $model.settings.autoCandidates)
                    Toggle("Killer cage helper", isOn: $model.settings.cageHelper)
                }
                Section("Mistakes") {
                    Toggle("Mistake highlighting", isOn: $model.settings.mistakeHighlighting)
                }
                Section("Convenience") {
                    Toggle("Auto-remove candidates", isOn: $model.settings.autoRemoveCandidates)
                    Toggle("Killer remaining sum", isOn: $model.settings.remainingSum)
                    Toggle("Highlight matching digits", isOn: $model.settings.highlightMatching)
                }
            }
            .navigationTitle("Settings")
            .toolbar { Button("Done") { dismiss() } }
        }
    }
}
