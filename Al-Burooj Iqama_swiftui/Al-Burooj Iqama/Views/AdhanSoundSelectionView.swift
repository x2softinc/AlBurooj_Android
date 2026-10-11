import SwiftUI
import AVFoundation

struct AdhanSoundSelectionView: View {
    @AppStorage(AdhanSoundPreference.storageKey)
    private var selectedAdhanSound = AdhanSoundOption.systemDefault.rawValue

    @State private var audioPlayer: AVAudioPlayer?
    @State private var previewingSound: AdhanSoundOption?

    var body: some View {
        List {
            Section {
                ForEach(AdhanSoundOption.allCases) { option in
                    soundRow(option)
                }
            } header: {
                Text("Select a sound")
            } footer: {
                Text("The selected sound is used only for Adhan notifications. Iqama notifications keep the default system sound.")
            }
        }
        .navigationTitle("Adhan Sound")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            stopSound()
        }
        .onChange(of: selectedAdhanSound) { _, _ in
            stopSound()

            Task {
                await NotificationScheduler().syncNotifications()
            }
        }
    }

    private func soundRow(_ option: AdhanSoundOption) -> some View {
        HStack {
            Button {
                selectedAdhanSound = option.rawValue
            } label: {
                HStack {
                    Text(option.displayName)

                    Spacer()

                    if selectedAdhanSound == option.rawValue {
                        Image(systemName: "checkmark.circle.fill")
                            .fontWeight(.semibold)
                            .foregroundStyle(Color("themeColor"))
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if option.resourceName != nil {
                Button {
                    togglePreview(for: option)
                } label: {
                    Image(systemName: isPreviewing(option) ? "stop.circle.fill" : "play.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Color("themeColor"))
                        .frame(width: 40, height: 32)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(isPreviewing(option) ? "Stop \(option.displayName)" : "Play \(option.displayName)")
            }
        }
    }

    private func isPreviewing(_ option: AdhanSoundOption) -> Bool {
        previewingSound == option && audioPlayer?.isPlaying == true
    }

    private func togglePreview(for option: AdhanSoundOption) {
        if isPreviewing(option) {
            stopSound()
        } else {
            playSound(option)
        }
    }

    private func playSound(_ option: AdhanSoundOption) {
        guard let url = option.previewURL else {
            return
        }

        // Stop any currently playing sound first
        stopSound()

        Task.detached {
            do {
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
                try AVAudioSession.sharedInstance().setActive(true)

                let player = try AVAudioPlayer(contentsOf: url)
                await MainActor.run {
                    audioPlayer = player
                    previewingSound = option
                }
                player.play()
            } catch {
                print("Could not play \(await option.displayName): \(error)")
                await MainActor.run {
                    stopSound()
                }
            }
        }
    }

    private func stopSound() {
        audioPlayer?.stop()
        audioPlayer = nil
        previewingSound = nil
    }
}

#Preview {
    NavigationStack {
        AdhanSoundSelectionView()
    }
}
