import ActivityKit
import Foundation
import MediaPlayer
import UIKit

/// Watches Apple Music, finds the lyrics, and keeps the lyrics card in sync.
@MainActor
final class LyricsEngine: ObservableObject {

    // MARK: What the screen shows

    @Published var title = ""
    @Published var artist = ""
    @Published var previousLine = ""
    @Published var currentLine = ""
    @Published var nextLine = ""
    @Published var hue: Double = 0.76
    @Published var status = "Tap play, then start a song in Apple Music."
    @Published var isRunning = false
    @Published var isPlaying = false

    /// Things the user needs to fix in iPhone Settings.
    @Published var needsLocation = false
    @Published var needsFrequentUpdates = false
    @Published var needsLiveActivities = false

    /// What happened the last time the phone was locked. Shown in Settings.
    @Published var healthReport: String = UserDefaults.standard.string(forKey: "healthReport")
        ?? "Nothing recorded yet. Start the lyrics, lock your phone for a minute, then come back here."

    // MARK: Settings (remembered between drives)

    /// Nudge timing if lyrics run early or late (seconds; + shows lines sooner).
    @Published var offset: Double = UserDefaults.standard.double(forKey: "timingOffset") {
        didSet { UserDefaults.standard.set(offset, forKey: "timingOffset") }
    }

    /// 0 = biggest text, 1 = balanced, 2 = whole lines.
    @Published var textSize: Int = (UserDefaults.standard.object(forKey: "textSize") as? Int) ?? 1 {
        didSet {
            UserDefaults.standard.set(textSize, forKey: "textSize")
            repace()
        }
    }

    @Published var showNextOnCarPlay: Bool = UserDefaults.standard.bool(forKey: "showNextOnCarPlay") {
        didSet { UserDefaults.standard.set(showNextOnCarPlay, forKey: "showNextOnCarPlay") }
    }

    /// Extra keep-awake using silent sound. Off unless the health check says the app fell asleep.
    @Published var soundBackup: Bool = UserDefaults.standard.bool(forKey: "soundBackup") {
        didSet {
            UserDefaults.standard.set(soundBackup, forKey: "soundBackup")
            guard isRunning else { return }
            if soundBackup {
                sound.start()
            } else {
                sound.stop()
            }
        }
    }

    // MARK: Inner workings

    private let player = MPMusicPlayerController.systemMusicPlayer
    private let location = LocationKeepAlive()
    private let sound = KeepAlive()
    private var clock = PlaybackClock()

    private var rawLines: [LyricLine] = []     // lyrics as downloaded
    private var lines: [LyricLine] = []        // lyrics prepared for the card
    private var cache: [String: [LyricLine]] = [:]
    private var songKey = ""
    private var songDuration: Double = 0
    private var lineIndex = -2
    private var tickCount = 0
    private var timer: Timer?
    private var fetchTask: Task<Void, Never>?
    private var activity: Activity<LyricsAttributes>?

    // Card updates. iOS ignores updates that come too fast, so they are spaced out.
    private var lastSent: LyricsAttributes.ContentState?
    private var lastSentAt = Date.distantPast
    private let minSpacing: TimeInterval = 2.0
    /// If the app stops refreshing the card for this long, the card says "paused".
    private let staleAfter: TimeInterval = 5 * 60
    /// Re-send an unchanged card this often so it never looks "paused" while we're running.
    private let refreshAfter: TimeInterval = 2 * 60

    // Battery saver: stop by ourselves when no music has played for a while.
    private var quietSince: Date?
    private let quietLimit: TimeInterval = 30 * 60

    // Health check: what happened while the app was off screen.
    private var lastTick = Date()
    private var hiddenSince: Date?
    private var hiddenSleep: TimeInterval = 0
    private var hiddenUpdates = 0
    private var hiddenLiveTicks = 0
    private var hiddenCarriedTicks = 0

    init() {
        location.onChange = { [weak self] in
            Task { @MainActor in
                self?.refreshWarnings()
            }
        }

        // If the app was shut down while lyrics were running last time, say so.
        let defaults = UserDefaults.standard
        if defaults.bool(forKey: "wasRunning") {
            defaults.set(false, forKey: "wasRunning")
            let stamp = defaults.double(forKey: "lastAlive")
            if stamp > 0 {
                let when = Date(timeIntervalSince1970: stamp).formatted(date: .abbreviated, time: .shortened)
                let report = "Last time, the app was closed while lyrics were running (last awake: \(when)). "
                    + "That happens if iOS shuts it down or you swipe it away."
                healthReport = report
                defaults.set(report, forKey: "healthReport")
            }
        }
    }

    // MARK: Start / stop

    func start() async {
        guard !isRunning else { return }

        let access = await LyricsEngine.requestMusicAccess()
        guard access == .authorized else {
            status = "Please allow access: Settings → Apps → LyricDash → Media & Apple Music."
            return
        }
        guard !isRunning else { return }

        isRunning = true
        UserDefaults.standard.set(true, forKey: "wasRunning")
        location.start()
        if soundBackup {
            sound.start()
        }
        player.beginGeneratingPlaybackNotifications()

        resetSong()
        currentLine = "Waiting for a song…"
        status = "Running. Play a song in Apple Music."
        quietSince = nil
        hiddenSince = nil
        lastTick = Date()

        // Clear any card left over from last time, then show a fresh one.
        // (iOS only lets an app start a card while the app is open on screen.)
        activity = nil
        lastSent = nil
        await endAllActivities()
        startActivity()
        refreshWarnings()

        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
        tick()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        fetchTask?.cancel()
        fetchTask = nil
        player.endGeneratingPlaybackNotifications()
        location.stop()
        sound.stop()

        isRunning = false
        isPlaying = false
        UserDefaults.standard.set(false, forKey: "wasRunning")
        resetSong()
        status = "Stopped."

        activity = nil
        lastSent = nil
        Task { await endAllActivities() }
    }

    // MARK: App shown / hidden

    /// Called when the app leaves the screen (phone locked or another app opened).
    func appWentToBackground() {
        guard isRunning else { return }
        hiddenSince = Date()
        hiddenSleep = 0
        hiddenUpdates = 0
        hiddenLiveTicks = 0
        hiddenCarriedTicks = 0
    }

    /// Called whenever the app comes back on screen.
    func appBecameActive() {
        refreshWarnings()
        guard isRunning else { return }

        let now = Date()
        if let since = hiddenSince {
            let gap = now.timeIntervalSince(lastTick)
            if gap > 3 {
                hiddenSleep += gap
            }
            let total = now.timeIntervalSince(since)
            if total > 20 {
                writeHealthReport(total: total)
            }
        }
        hiddenSince = nil

        if soundBackup {
            sound.ensureRunning()
        }
        if cardIsGone {
            activity = nil
            lastSent = nil
            startActivity()
            if activity != nil {
                status = lines.isEmpty ? "Running. Play a song in Apple Music." : "Showing lyrics."
            }
        }
    }

    // MARK: Main loop (4 times a second)

    private func tick() {
        guard isRunning else { return }

        let now = Date()
        let gap = now.timeIntervalSince(lastTick)
        lastTick = now
        if hiddenSince != nil && gap > 3 {
            hiddenSleep += gap      // the app was asleep for this long
        }

        tickCount += 1
        if tickCount % 20 == 0 {
            UserDefaults.standard.set(now.timeIntervalSince1970, forKey: "lastAlive")
            if soundBackup {
                sound.ensureRunning()
            }
        }

        let onScreen = UIApplication.shared.applicationState == .active
        var playingNow = false

        if let item = player.nowPlayingItem {
            let key = "\(item.title ?? "")|\(item.artist ?? "")|\(Int(length(of: item)))"
            let isNewSong = key != songKey
            if isNewSong {
                songChanged(item, key: key)
            }

            let reported = player.currentPlaybackTime
            let reading = clock.read(
                reported: reported.isFinite ? reported : 0,
                reportedPlaying: player.playbackState == .playing,
                isNewSong: isNewSong,
                onScreen: onScreen,
                duration: songDuration,
                now: now
            )
            playingNow = reading.isPlaying
            if hiddenSince != nil {
                if reading.isCarried {
                    hiddenCarriedTicks += 1
                } else if reading.isPlaying {
                    hiddenLiveTicks += 1
                }
            }
            updateLine(at: reading.position + offset)
        }

        if isPlaying != playingNow {
            isPlaying = playingNow
        }

        // Battery saver.
        if playingNow {
            quietSince = nil
        } else if let since = quietSince {
            if now.timeIntervalSince(since) > quietLimit {
                stop()
                status = "Stopped to save battery (no music for 30 minutes)."
                return
            }
        } else {
            quietSince = now
        }

        sendCardIfNeeded(now: now)
    }

    private func updateLine(at time: Double) {
        guard !lines.isEmpty else { return }
        let index = lines.lastIndex(where: { $0.time <= time }) ?? -1
        guard index != lineIndex else { return }
        lineIndex = index
        previousLine = index >= 1 ? shown(lines[index - 1].text) : ""
        currentLine = index >= 0 ? shown(lines[index].text) : "♪"
        nextLine = index + 1 < lines.count ? shown(lines[index + 1].text) : ""
    }

    private func songChanged(_ item: MPMediaItem, key: String) {
        resetSong()
        songKey = key

        let songTitle = item.title ?? ""
        let songArtist = item.artist ?? ""
        let duration = length(of: item)
        songDuration = duration
        title = songTitle.isEmpty ? "Unknown song" : songTitle
        artist = songArtist
        hue = Palette.hue(for: songTitle + songArtist)

        guard !songTitle.isEmpty else {
            currentLine = "♪"
            return
        }

        if let saved = cache[key] {
            rawLines = saved          // played before: no need to download again
            repace()
            status = "Showing lyrics."
            return
        }

        currentLine = "Finding lyrics…"
        status = "Finding lyrics…"

        fetchTask = Task { @MainActor [weak self] in
            let found = await LyricsService.fetch(title: songTitle, artist: songArtist, duration: duration)
            guard let self, !Task.isCancelled, key == self.songKey else { return }
            if let found, !found.isEmpty {
                self.cache[key] = found
                self.rawLines = found
                self.repace()       // the next tick (a quarter second away) shows the right line
                self.status = "Showing lyrics."
            } else {
                self.currentLine = "No synced lyrics for this song"
                self.status = "No synced lyrics found for this song."
            }
        }
    }

    private func resetSong() {
        fetchTask?.cancel()
        fetchTask = nil
        songKey = ""
        songDuration = 0
        rawLines = []
        lines = []
        lineIndex = -2
        title = ""
        artist = ""
        previousLine = ""
        currentLine = ""
        nextLine = ""
    }

    /// Re-prepares the lyrics for the card (after a download, or when the text size setting changes).
    private func repace() {
        let maxChars: Int
        switch textSize {
        case 0: maxChars = 26
        case 2: maxChars = 0
        default: maxChars = 38
        }
        lines = LinePacer.pace(rawLines, maxChars: maxChars)
        lineIndex = -2
    }

    private func shown(_ text: String) -> String {
        text.isEmpty ? "♪" : text
    }

    /// Song length in seconds, or 0 if iOS doesn't know it yet.
    private func length(of item: MPMediaItem) -> Double {
        let seconds = item.playbackDuration
        return seconds.isFinite && seconds > 0 && seconds < 86_400 ? seconds : 0
    }

    // MARK: The lyrics card (a Live Activity: CarPlay, Lock Screen, Dynamic Island)

    private var cardState: LyricsAttributes.ContentState {
        LyricsAttributes.ContentState(
            title: title,
            artist: artist,
            currentLine: currentLine,
            nextLine: nextLine,
            hue: hue,
            showNext: showNextOnCarPlay
        )
    }

    private var cardIsGone: Bool {
        guard let activity else { return true }
        return activity.activityState == .ended || activity.activityState == .dismissed
    }

    private func startActivity() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            status = "Turn on Live Activities: Settings → Apps → LyricDash → Live Activities."
            return
        }
        let state = cardState
        do {
            activity = try Activity<LyricsAttributes>.request(
                attributes: LyricsAttributes(),
                content: ActivityContent(state: state, staleDate: Date().addingTimeInterval(staleAfter), relevanceScore: 100),
                pushType: nil
            )
            lastSent = state
            lastSentAt = Date()
        } catch {
            // Usually means the app wasn't fully on screen yet. It is retried when the app becomes active.
            status = "Couldn't show the lyrics card yet. Keep LyricDash open for a second."
        }
    }

    /// Sends the newest lyrics to the card, at most once every 2 seconds.
    private func sendCardIfNeeded(now: Date) {
        guard let activity else { return }
        if cardIsGone {
            self.activity = nil
            lastSent = nil
            status = "The lyrics card was closed. Open LyricDash to bring it back."
            return
        }

        let state = cardState
        let sinceLast = now.timeIntervalSince(lastSentAt)
        let changed = state != lastSent
        guard changed || sinceLast > refreshAfter else { return }
        guard sinceLast >= minSpacing else { return }

        lastSent = state
        lastSentAt = now
        if hiddenSince != nil {
            hiddenUpdates += 1
        }
        let content = ActivityContent(state: state, staleDate: now.addingTimeInterval(staleAfter), relevanceScore: 100)
        Task { await activity.update(content) }
    }

    private func endAllActivities() async {
        for old in Activity<LyricsAttributes>.activities {
            await old.end(nil, dismissalPolicy: .immediate)
        }
    }

    // MARK: Warnings and health check

    private func refreshWarnings() {
        let info = ActivityAuthorizationInfo()
        let cardsOn = info.areActivitiesEnabled
        let frequentOn = info.frequentPushesEnabled
        let locationBlocked = location.status == .notAllowed

        if needsLiveActivities != !cardsOn {
            needsLiveActivities = !cardsOn
        }
        if needsFrequentUpdates != (cardsOn && !frequentOn) {
            needsFrequentUpdates = cardsOn && !frequentOn
        }
        if needsLocation != locationBlocked {
            needsLocation = locationBlocked
        }
    }

    private func writeHealthReport(total: TimeInterval) {
        var rows: [String] = []
        rows.append("Last time the app was off screen (\(pretty(total))):")

        if hiddenSleep > 5 {
            rows.append("• Stayed awake: NO. iOS put it to sleep for about \(pretty(hiddenSleep)).")
        } else {
            rows.append("• Stayed awake: yes.")
        }

        rows.append("• Lyric updates sent to the card: \(hiddenUpdates).")

        if hiddenLiveTicks + hiddenCarriedTicks == 0 {
            rows.append("• Song position: no music was playing.")
        } else if hiddenCarriedTicks > hiddenLiveTicks {
            rows.append("• Song position: kept by LyricDash's own clock (normal when locked).")
        } else {
            rows.append("• Song position: read live from Apple Music.")
        }

        let locationText: String
        switch location.status {
        case .on: locationText = "on"
        case .notAllowed: locationText = "NOT ALLOWED"
        case .waitingForPermission: locationText = "waiting for permission"
        case .off: locationText = "off"
        }
        rows.append("• Keep-awake: location \(locationText), sound backup \(soundBackup ? "on" : "off").")

        let report = rows.joined(separator: "\n")
        healthReport = report
        UserDefaults.standard.set(report, forKey: "healthReport")
    }

    private func pretty(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        if total < 60 {
            return "\(total) s"
        }
        return "\(total / 60) min \(total % 60) s"
    }

    // MARK: Permission

    /// Kept off the main actor on purpose: iOS answers this on a background thread.
    nonisolated private static func requestMusicAccess() async -> MPMediaLibraryAuthorizationStatus {
        await withCheckedContinuation { continuation in
            MPMediaLibrary.requestAuthorization { result in
                continuation.resume(returning: result)
            }
        }
    }
}
