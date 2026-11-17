import Foundation

/// Works out where we are in the song.
///
/// While LyricDash is on screen, Apple Music tells us the exact position.
/// Once the phone is locked, Apple Music stops reporting: the position freezes
/// and it claims to be paused even while the song plays. So when that happens
/// we keep our own clock running from the last real reading.
struct PlaybackClock {
    struct Reading {
        let position: Double
        let isPlaying: Bool
        /// True when the position came from our own clock, not from Apple Music.
        let isCarried: Bool
    }

    private var anchorPosition: Double = 0
    private var anchorDate = Date()
    private var lastReported: Double = -1
    private var playingAtAnchor = false

    mutating func reset() {
        anchorPosition = 0
        anchorDate = Date()
        lastReported = -1
        playingAtAnchor = false
    }

    mutating func read(reported: Double,
                       reportedPlaying: Bool,
                       isNewSong: Bool,
                       onScreen: Bool,
                       duration: Double,
                       now: Date) -> Reading {
        let fresh = isNewSong || reported != lastReported

        if fresh {
            let movedForward = !isNewSong && reported > lastReported
            if onScreen {
                // On screen, Apple Music's "playing / paused" is trustworthy.
                playingAtAnchor = reportedPlaying
            } else if isNewSong || movedForward {
                // Off screen it isn't, but a new song or a position that moved
                // forward proves the music is running.
                playingAtAnchor = true
            }
            lastReported = reported
            anchorPosition = reported
            anchorDate = now
        }

        if onScreen {
            return Reading(position: reported, isPlaying: reportedPlaying, isCarried: false)
        }
        if fresh {
            return Reading(position: reported, isPlaying: playingAtAnchor, isCarried: false)
        }
        if playingAtAnchor {
            let carried = anchorPosition + now.timeIntervalSince(anchorDate)
            // Past the end of the song we can't know what's playing: wait for a real reading.
            if duration <= 0 || carried <= duration {
                return Reading(position: carried, isPlaying: true, isCarried: true)
            }
        }
        return Reading(position: reported, isPlaying: false, isCarried: false)
    }
}
