import SwiftUI
import SudokuGame

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            Form {
                Section("Appearance") {
                    Picker("Appearance", selection: $model.settings.appearance) {
                        Text("System").tag(Appearance.system)
                        Text("Light").tag(Appearance.light)
                        Text("Dark").tag(Appearance.dark)
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("appearancePicker")
                }
                Section("Assists (using them counts against a clean solve)") {
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
