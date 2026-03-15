import SwiftUI

struct VoicePreferencesView: View {
    @EnvironmentObject private var voiceSettings: VoiceSettings

    var body: some View {
        Form {
            Section("Voice Input") {
                Picker("Language", selection: $voiceSettings.language) {
                    ForEach(VoiceLanguage.allCases) { language in
                        Text(language.displayTitle)
                            .tag(language)
                    }
                }
                .pickerStyle(.radioGroup)

                Text("Selected language is sent to Whisper as `language_hint` for voice updates.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(20)
        .frame(width: 360)
    }
}
