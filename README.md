# hushbrew

[![CI](https://github.com/sandeepyadav1478/homebrew-hushbrew/actions/workflows/ci.yml/badge.svg)](https://github.com/sandeepyadav1478/homebrew-hushbrew/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

Automatic daily Homebrew upgrades for macOS that stay out of your way.

Runs as a LaunchAgent, detects meetings before starting, throttles bandwidth so your network isn't saturated, and sends macOS notifications when done.

## Features

- **Meeting-aware** — Detects Zoom calls, Slack huddles, and active microphone usage. Skips the upgrade and retries later.
- **Power-aware** — Skips upgrades if battery is below 15% and not plugged in. Runs normally when on AC power or battery above 15%.
- **Bandwidth throttling** — Measures your current speed and caps brew downloads at 60% so you don't notice.
- **Once-daily** — Runs at 10 AM, with automatic retries at 2 PM and 6 PM if earlier runs were blocked.
- **Exclusion lists** — Pin packages you don't want auto-upgraded via a config file.
- **Safe** — Lock file prevents concurrent runs, timeouts prevent hangs, disk space checks prevent filling your drive.
- **Low priority** — Runs with `nice` and `LowPriorityBackgroundIO` so it doesn't affect your work.
- **Notifications** — macOS notifications report success or any issues.
- **Log rotation** — Keeps logs under 1 MB automatically.
- **Zero dependencies** — Pure bash. Only requires macOS and Homebrew.

## Requirements

- macOS (Apple Silicon or Intel)
- [Homebrew](https://brew.sh)

## Install

### Using Homebrew (Recommended)

```bash
brew tap sandeepyadav1478/hushbrew
brew install hushbrew
hushbrew start
```

The `hushbrew start` command will:
1. Run setup (first time only) - installs scripts to `~/.local/bin/` and creates config
2. Start the LaunchAgent that triggers at 10 AM, 2 PM, and 6 PM daily

### Manual Installation (Alternative)

```bash
git clone https://github.com/sandeepyadav1478/homebrew-hushbrew.git
cd homebrew-hushbrew
./install.sh
```

Or use make:

```bash
make install
```

## Uninstall

### Using Homebrew

```bash
hushbrew stop        # Stops service and removes all files
brew uninstall hushbrew
```

This removes everything except config (preserved for reinstalls).
To remove config too:
```bash
rm -rf ~/.config/hushbrew
```

### Manual Uninstall

```bash
./uninstall.sh
# or
make uninstall
```

Config is preserved — delete it manually if you don't need it:

```bash
rm -rf ~/.config/hushbrew
```

## Configuration

Edit `~/.config/hushbrew/config` to exclude packages from auto-upgrade:

```bash
# Space-separated package names
EXCLUDED_FORMULAE="node python@3.11"
EXCLUDED_CASKS="docker-desktop"
```

### Schedule

The LaunchAgent runs at three times daily:

| Slot | Time | Purpose |
|------|------|---------|
| Primary | 10:00 AM | First attempt |
| Retry 1 | 2:00 PM | If 10 AM was blocked by a meeting |
| Retry 2 | 6:00 PM | If 2 PM was also blocked |

Only the first successful run actually upgrades. The rest exit immediately since the "already updated today" check passes.

To change the schedule, edit the plist before installing, or modify `~/Library/LaunchAgents/com.local.hushbrew.plist` and reload:

```bash
launchctl bootout gui/$(id -u)/com.local.hushbrew
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.local.hushbrew.plist
```

## How Meeting Detection Works

The script checks four things in order:

1. **Zoom `CptHost` process** — This process only exists during an active Zoom call.
2. **Zoom UDP audio** — If Zoom is running with active UDP connections (audio streaming), a meeting is likely in progress.
3. **Slack huddle** — Slack uses WebRTC (UDP on high ports) for huddles. Normal Slack messaging uses UDP port 443 (QUIC), which is excluded to avoid false positives.
4. **Microphone active** — Catches any other meeting app (Teams, Google Meet, FaceTime) by checking if the macOS audio input hardware is in use.

If any check triggers, the upgrade is deferred to the next scheduled slot.

## How Power Detection Works

The script uses `pmset` to check your Mac's power status:

1. **AC Power** — If connected to AC power (charging), the upgrade proceeds normally.
2. **Battery Power** — If running on battery:
   - **Above 15%** — Proceeds with the upgrade
   - **Below 15%** — Skips the upgrade to preserve battery, retries at the next scheduled slot

This prevents draining your battery during important work. You'll get a notification explaining why the upgrade was deferred.

## Logs

```bash
# View the log
cat ~/.local/log/hushbrew.log

# Follow in real time (run manually first)
tail -f ~/.local/log/hushbrew.log

# Check last run date
cat ~/.local/log/hushbrew.lastrun
```

## Run Manually

```bash
~/.local/bin/hushbrew.sh
```

## How It Works

1. Check if already updated today (exit if so)
2. Acquire a lock file to prevent concurrent runs
3. Detect active meetings/huddles/microphone usage
4. Measure bandwidth and set a download speed cap at 60%
5. Check internet connectivity and disk space
6. Run `brew update`
7. Upgrade outdated formulae (excluding configured exclusions)
8. Upgrade outdated casks (excluding configured exclusions)
9. Run `brew cleanup --prune=7`
10. Verify no packages are still outdated, check for broken dependencies
11. Send a macOS notification with the result

## Project Structure

```
bin/
  hushbrew.sh              Main upgrade script
  brew-curl                Bandwidth-limiting curl wrapper
launchd/
  com.local.hushbrew.plist LaunchAgent template
install.sh                 Installer
uninstall.sh               Uninstaller
Makefile                   lint / install / uninstall targets
.github/
  workflows/ci.yml         ShellCheck + plist validation CI
  ISSUE_TEMPLATE/          Bug report and feature request templates
  PULL_REQUEST_TEMPLATE.md PR template
```

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

[MIT](LICENSE)
