import Charts
import SwiftData
import SwiftUI
import SudokuCore
import SudokuGame

struct StatsView: View {
    @Query(sort: \GameRecord.endDate) private var stored: [GameRecord]
    @Environment(\.dismiss) private var dismiss
    @State private var mode: Mode = .classic
    @State private var chartTier: Tier = .hard

    private var records: [GameRecordData] { stored.compactMap(\.data) }

    var body: some View {
        NavigationStack {
            List {
                Picker("Mode", selection: $mode) {
                    Text("Classic").tag(Mode.classic)
                    Text("Killer").tag(Mode.killer)
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)

                Section("By difficulty") {
                    ForEach(Tier.allCases, id: \.self) { tier in tierRow(tier) }
                }

                Section("Progress") {
                    Picker("Tier", selection: $chartTier) {
                        ForEach(Tier.allCases, id: \.self) { Text($0.name.capitalized).tag($0) }
                    }
                    let points = StatsCalculator.progress(records, mode: mode, tier: chartTier)
                    if points.isEmpty {
                        Text("Win a \(chartTier.name) game to see your times.").foregroundStyle(.secondary)
                    } else {
                        Chart(points, id: \.date) { p in
                            LineMark(x: .value("Date", p.date), y: .value("Minutes", p.seconds / 60))
                            PointMark(x: .value("Date", p.date), y: .value("Minutes", p.seconds / 60))
                        }
                        .chartYAxisLabel("Minutes")
                        .frame(height: 180)
                    }
                }

                Section("Assistance") {
                    let a = StatsCalculator.assistance(records, mode: mode)
                    stat("Clean solves", a.games == 0 ? "—" : "\(a.cleanSolves) of \(a.games)")
                    stat("Mistakes (highlighting on)", a.mistakeGames == 0 ? "—" : "\(a.mistakes) in \(a.mistakeGames) games")
                    stat("Hints", ["nudge", "spotlight", "lesson", "showMe"].map { "\(a.hints[$0, default: 0])" }.joined(separator: " / "))
                    stat("Checks · Reveals · Assists", "\(a.checks) · \(a.reveals) · \(a.assists)")
                }

                Section("Techniques you've beaten") {
                    let t = StatsCalculator.techniques(records, mode: mode)
                    if t.isEmpty { Text("None yet.").foregroundStyle(.secondary) }
                    ForEach(t, id: \.technique) { stat($0.technique.displayName, "\($0.count)") }
                }

                Section("Most abandoned") {
                    let rates = StatsCalculator.abandonRates(records, mode: mode).filter { $0.rate > 0 }
                    if rates.isEmpty { Text("Nothing abandoned.").foregroundStyle(.secondary) }
                    ForEach(rates, id: \.tier) { stat($0.tier.name.capitalized, "\(Int(($0.rate * 100).rounded()))%") }
                }
            }
            .navigationTitle("Stats")
            .toolbar { Button("Done") { dismiss() } }
        }
    }

    private func tierRow(_ tier: Tier) -> some View {
        let s = StatsCalculator.tier(records, mode: mode, tier: tier)
        return VStack(alignment: .leading, spacing: 6) {
            Text(tier.name.capitalized).font(.headline)
            HStack {
                mini("Played", "\(s.played)")
                mini("Won", "\(s.won)")
                mini("Win %", s.played == 0 ? "—" : "\(Int((s.winRate * 100).rounded()))")
                mini("Best", s.bestTime.map(GameView.clock) ?? "—")
                mini("Avg", s.averageTime.map(GameView.clock) ?? "—")
                mini("Streak", "\(s.currentStreak)/\(s.bestStreak)")
            }
        }
        .padding(.vertical, 2)
    }

    private func mini(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.subheadline.monospacedDigit()).lineLimit(1).minimumScaleFactor(0.7)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func stat(_ label: String, _ value: String) -> some View {
        HStack { Text(label); Spacer(); Text(value).foregroundStyle(.secondary).monospacedDigit() }
    }
}
