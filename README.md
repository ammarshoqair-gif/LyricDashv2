# LyricDash 2.0

Shows synced lyrics on CarPlay for whatever's playing in Apple Music.
Built for personal use. No Mac needed.

## What's new in 2.0
- **Lyrics keep moving when the phone is locked.**
- **Bigger CarPlay text.** Long lines are split into short pieces, and the text is sized to fill the card without being cut off.
- **New look.** Moving colors that change with every song, a new lyrics card, and an app icon.
- **Health check.** If something goes wrong, the app can tell you (and Claude) why.

## How to update (about 15 minutes)

### 1. Upload the new files to GitHub
1. Unzip this folder on your PC.
2. Open your `LyricDash` repo on github.com.
3. Click **Add file → Upload files**.
4. Open the unzipped folder, select **all the files** (Ctrl+A), and drag them in. There are no sub-folders this time.
5. Click **Commit changes**. Files with the same name are replaced.

### 2. Get the new app
1. Open the **Actions** tab. A new build starts by itself. Wait for the green check (5 to 10 minutes, sometimes longer in the queue).
2. Open the finished run. Under **Artifacts**, download `LyricDash-ipa` and unzip it.

**Red X?** Download `build-log` from the same place (or screenshot the red lines) and send it to Claude.

### 3. Install it over the old one
1. Plug in your iPhone and open Sideloadly.
2. Drag in the new `LyricDash.ipa`. Use the **same Apple ID** as before.
3. Leave **Remove app extensions** OFF. Click **Start**.

### 4. First run (do this once, at home)
1. Open LyricDash and tap the big **play** button.
2. When asked about location, choose **Allow While Using App**.
   - This is what keeps lyrics moving when the phone is locked.
   - Your location is never saved or sent anywhere.
3. If a yellow warning box appears in the app, tap it and fix that setting. The important one:
   **Settings → Apps → LyricDash → Live Activities → More Frequent Updates = ON**.
4. Play a song. Lock the phone. Watch the Lock Screen for a minute: the lyrics should keep moving.

## In the car
1. Connect to CarPlay and play music.
2. Open LyricDash, tap **play**, then lock the phone.
3. The lyrics card is on the CarPlay **Dashboard**.
4. Tap **stop** when you're done. If you forget, it stops by itself after 30 minutes with no music.

## Settings (the slider button, top right)
- **Text size**
  - *Biggest*: shortest pieces, largest text.
  - *Balanced*: the default.
  - *Whole lines*: each line in one go, smaller text.
- **Also show the next line**: adds the upcoming line under the current one on CarPlay.
- **Sound backup**: leave off. Only turn it on if the health check says the app fell asleep.
- **Health check**: shows what happened the last time the phone was locked.

## If something's off
- **Lyrics freeze when locked:** open LyricDash → Settings → Health check, and send Claude a screenshot.
- **A blue arrow or pill at the top of the phone:** normal. That's the low-power location session.
- **Lyrics keep going after you pause while locked:** known limit. iOS hides the pause from the app while the phone is locked. They re-sync when the music plays again.
- **Lyrics run a bit early or late:** use the **Timing** − / + buttons. The app remembers it.
- **No card on CarPlay:** on the car screen, open Settings and check Live Activities is on. Make sure you're on the Dashboard, not full-screen Maps.
- **Card says "Lyrics paused":** open LyricDash once and it picks back up.
- **"No synced lyrics for this song":** the free database doesn't have that song.

## Good to know
- With a free Apple ID, the app stops opening after 7 days. Run Sideloadly again to renew.
- Lyrics come from LRCLIB (lrclib.net), a free community database.
- Best for passengers or when stopped. Keep your eyes on the road.
