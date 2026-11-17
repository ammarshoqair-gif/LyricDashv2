import SwiftUI
import UIKit

struct ContentView: View {
    @EnvironmentObject var engine: LyricsEngine
    @Environment(\.scenePhase) private var scenePhase
    @State private var showSettings = false

    var body: some View {
        ZStack {
            AuroraBackground(hue: engine.hue, lively: engine.isRunning)

            VStack(spacing: 0) {
                header
                songInfo
                Spacer(minLength: 10)
                stage
                Spacer(minLength: 10)
                notices
                controls
            }
            .padding(.horizontal, 22)
            .padding(.top, 10)
            .padding(.bottom, 16)
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(engine)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                engine.appBecameActive()
            } else if phase == .background {
                engine.appWentToBackground()
            }
        }
    }

    // MARK: Top bar

    private var header: some View {
        HStack(spacing: 10) {
            Text("LyricDash")
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(
                    LinearGradient(colors: [Color.white, Palette.accent(engine.hue)],
                                   startPoint: .leading, endPoint: .trailing)
                )

            Spacer()

            HStack(spacing: 6) {
                Circle()
                    .fill(badgeColor)
                    .frame(width: 8, height: 8)
                    .scaleEffect(engine.isRunning ? 1.5 : 1.0)
                    .animation(
                        engine.isRunning
                            ? Animation.easeInOut(duration: 0.9).repeatForever(autoreverses: true)
                            : Animation.easeInOut(duration: 0.3),
                        value: engine.isRunning
                    )
                Text(badgeText)
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .glassBox(corner: 16)

            Button {
                showSettings = true
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Color.white)
                    .frame(width: 38, height: 38)
                    .glassBox(corner: 19)
            }
        }
    }

    private var badgeText: String {
        if !engine.isRunning { return "OFF" }
        return engine.isPlaying ? "LIVE" : "READY"
    }

    private var badgeColor: Color {
        if !engine.isRunning { return Color.white.opacity(0.4) }
        return engine.isPlaying ? Color.green : Color.yellow
    }

    private var songInfo: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(engine.title.isEmpty ? "Nothing playing" : engine.title)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(Color.white)
                .lineLimit(1)
            Text(engine.artist.isEmpty ? "Apple Music" : engine.artist)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.6))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 18)
    }

    // MARK: Lyrics

    private var stage: some View {
        VStack(spacing: 20) {
            if engine.isRunning {
                Text(engine.previousLine.isEmpty ? " " : engine.previousLine)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.30))
                    .lineLimit(2)

                Text(engine.currentLine.isEmpty ? "♪" : engine.currentLine)
                    .font(.system(size: 38, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.white)
                    .shadow(color: Palette.accent(engine.hue).opacity(0.9), radius: 18)
                    .lineLimit(5)
                    .minimumScaleFactor(0.5)
                    .id(engine.currentLine)
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    ))

                Text(engine.nextLine.isEmpty ? " " : engine.nextLine)
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.45))
                    .lineLimit(2)
            } else {
                Image(systemName: "music.mic")
                    .font(.system(size: 64, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(colors: [Palette.accent(engine.hue), Palette.second(engine.hue)],
                                       startPoint: .top, endPoint: .bottom)
                    )
                Text("Ready when you are")
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.white)
                Text("Tap play, start a song in Apple Music, then lock your phone and drive.")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.6))
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .animation(.spring(response: 0.45, dampingFraction: 0.82), value: engine.currentLine)
        .animation(.easeInOut(duration: 0.4), value: engine.isRunning)
    }

    // MARK: Things to fix in Settings

    @ViewBuilder
    private var notices: some View {
        if engine.needsLocation {
            notice("Lyrics will freeze when your phone locks",
                   "Tap to allow Location (While Using). It only keeps the app awake.")
        }
        if engine.needsFrequentUpdates {
            notice("Turn on More Frequent Updates",
                   "Tap, then open Live Activities. Without it lyrics stop after 30 seconds.")
        }
        if engine.needsLiveActivities {
            notice("Live Activities are off",
                   "Tap, then turn on Live Activities so the card can show on CarPlay.")
        }
    }

    private func notice(_ title: String, _ detail: String) -> some View {
        Button {
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Color.yellow)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                    Text(detail)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .opacity(0.75)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .opacity(0.6)
            }
            .multilineTextAlignment(.leading)
            .foregroundStyle(Color.white)
            .padding(12)
            .glassBox(corner: 16)
        }
        .padding(.bottom, 10)
    }

    // MARK: Buttons

    private var controls: some View {
        VStack(spacing: 16) {
            HStack(spacing: 6) {
                nudgeButton("minus") {
                    engine.offset = max(-5, engine.offset - 0.5)
                }
                VStack(spacing: 1) {
                    Text("TIMING")
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .opacity(0.55)
                    Text(timingText)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .monospacedDigit()
                }
                .frame(width: 120)
                nudgeButton("plus") {
                    engine.offset = min(5, engine.offset + 0.5)
                }
            }
            .foregroundStyle(Color.white)
            .padding(6)
            .glassBox(corner: 28)

            Button {
                if engine.isRunning {
                    engine.stop()
                } else {
                    Task { await engine.start() }
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(colors: [Palette.accent(engine.hue), Palette.second(engine.hue)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .frame(width: 86, height: 86)
                        .shadow(color: Palette.accent(engine.hue).opacity(0.75), radius: engine.isRunning ? 28 : 12)
                    Image(systemName: engine.isRunning ? "stop.fill" : "play.fill")
                        .font(.system(size: 30, weight: .black))
                        .foregroundStyle(Color.white)
                }
            }

            Text(engine.status)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.65))
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
    }

    private var timingText: String {
        if engine.offset == 0 { return "In sync" }
        let amount = String(format: "%.1f s", abs(engine.offset))
        return engine.offset > 0 ? amount + " early" : amount + " late"
    }

    private func nudgeButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .heavy))
                .frame(width: 44, height: 44)
                .background(Color.white.opacity(0.14), in: Circle())
        }
    }
}
