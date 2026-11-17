import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var engine: LyricsEngine
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Text size", selection: $engine.textSize) {
                        Text("Biggest").tag(0)
                        Text("Balanced").tag(1)
                        Text("Whole lines").tag(2)
                    }
                    .pickerStyle(.segmented)

                    Toggle("Also show the next line", isOn: $engine.showNextOnCarPlay)
                } header: {
                    Text("CarPlay card")
                } footer: {
                    Text("Biggest and Balanced split long lines into short pieces, so the words stay large and are never cut off. Whole lines shows each line in one go, in smaller text.")
                }

                Section {
                    Toggle("Sound backup", isOn: $engine.soundBackup)
                } header: {
                    Text("Staying awake")
                } footer: {
                    Text("LyricDash keeps a low-power location session open so iOS lets it run while your phone is locked. Your location is never saved or sent anywhere. Leave Sound backup off unless the health check below says the app fell asleep.")
                }

                Section {
                    Text(engine.healthReport)
                        .font(.footnote)
                        .textSelection(.enabled)
                } header: {
                    Text("Health check")
                } footer: {
                    Text("If lyrics ever freeze, open LyricDash, come here, and send a screenshot of this box.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .preferredColorScheme(.dark)
    }
}
