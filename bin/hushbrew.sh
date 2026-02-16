#!/bin/bash
#
# hushbrew — runs once daily, skips if a meeting/huddle is active.
# Retries every 4 hours (via LaunchAgent) until a clear window is found.
#
# Features:
#   - Meeting detection (Zoom, Slack huddle, microphone-in-use)
#   - Power-aware (skips if battery <15% and not on AC)
#   - Bandwidth throttling (caps downloads at 60% of detected speed)
#   - macOS notifications for status/errors
#   - Exclusion lists for formulae and casks
#   - Log rotation, disk space checks, timeout protection
#
# Log:    ~/.local/log/hushbrew.log
# State:  ~/.local/log/hushbrew.lastrun
# Lock:   /tmp/hushbrew.lock
# Config: ~/.config/hushbrew/config

set -euo pipefail

# ══════════════════════════════════════════════════════════════
#  Detect Homebrew prefix (Apple Silicon vs Intel)
# ══════════════════════════════════════════════════════════════

if [ -x /opt/homebrew/bin/brew ]; then
    BREW_PREFIX="/opt/homebrew"
elif [ -x /usr/local/bin/brew ]; then
    BREW_PREFIX="/usr/local"
else
    BREW_PREFIX="$(brew --prefix 2>/dev/null || echo /opt/homebrew)"
fi
BREW="$BREW_PREFIX/bin/brew"

if [ ! -x "$BREW" ]; then
    echo "ERROR: Homebrew not found at $BREW" >&2
    exit 1
fi

# ══════════════════════════════════════════════════════════════
#  Paths & State
# ══════════════════════════════════════════════════════════════

LOG="$HOME/.local/log/hushbrew.log"
STATE="$HOME/.local/log/hushbrew.lastrun"
LOCKFILE="/tmp/hushbrew.lock"
CONFIG="$HOME/.config/hushbrew/config"
TODAY=$(date +%Y-%m-%d)

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') | $1" >> "$LOG"
}

# Rotate log if > 1MB
if [ -f "$LOG" ] && [ "$(stat -f%z "$LOG" 2>/dev/null || echo 0)" -gt 1048576 ]; then
    mv "$LOG" "$LOG.old"
fi

# ── Already updated today? Exit immediately (costs nothing) ──
if [ -f "$STATE" ] && [ "$(cat "$STATE")" = "$TODAY" ]; then
    exit 0
fi

# ── Prevent concurrent runs (with another manual brew or this script) ──
if ! mkdir "$LOCKFILE" 2>/dev/null; then
    log "SKIP: Another hushbrew or brew process is running"
    exit 0
fi
trap 'rmdir "$LOCKFILE" 2>/dev/null' EXIT

# ── Check if brew itself is already running ──
if pgrep -f "$BREW_PREFIX/bin/brew" > /dev/null 2>&1; then
    log "SKIP: A manual brew process is already running"
    exit 0
fi

# ══════════════════════════════════════════════════════════════
#  Load Configuration
# ══════════════════════════════════════════════════════════════

# Defaults
EXCLUDED_FORMULAE=""
EXCLUDED_CASKS=""
UPGRADE_STRATEGY="all"  # Options: "all" or "leaves"

# Override from config file if it exists
if [ -f "$CONFIG" ]; then
    # shellcheck source=/dev/null
    source "$CONFIG"
fi

# ══════════════════════════════════════════════════════════════
#  Meeting / Huddle Detection
# ══════════════════════════════════════════════════════════════

blocked_by=""

# 1. Zoom meeting — CptHost is Zoom's meeting-host process.
#    It ONLY exists when the user is actively in a Zoom call.
if pgrep -x "CptHost" > /dev/null 2>&1; then
    blocked_by="Zoom meeting"
fi

# 2. Zoom meeting — secondary check via Zoom's audio device.
#    When in a meeting, Zoom activates its virtual audio device
#    which creates an active IOAudio stream.
if [ -z "$blocked_by" ] && pgrep -xq "zoom.us" 2>/dev/null; then
    zoom_audio=$(lsof -c zoom.us -a -i UDP 2>/dev/null | grep -c "UDP" || true)
    if [ "${zoom_audio:-0}" -gt 0 ]; then
        blocked_by="Zoom meeting (UDP audio)"
    fi
fi

# 3. Slack huddle — When in a huddle, Slack establishes WebRTC
#    connections using UDP on random high ports for real-time audio.
#    Normal Slack uses QUIC/HTTP3 (UDP port 443) for messaging —
#    we must EXCLUDE port 443 to avoid false positives.
if [ -z "$blocked_by" ] && pgrep -xq "Slack" 2>/dev/null; then
    slack_webrtc=$(lsof -c Slack -a -i UDP 2>/dev/null | grep "UDP" | grep -v ":https" | grep -c "UDP" || true)
    if [ "${slack_webrtc:-0}" -gt 0 ]; then
        blocked_by="Slack huddle"
    fi
fi

# 4. General catch-all — check if the macOS microphone is actively
#    in use by ANY app. Covers Teams, Meet, FaceTime, etc.
#    When mic is active, the system's audio input IOAudioEngine
#    moves to running state.
if [ -z "$blocked_by" ]; then
    mic_active=$(ioreg -c AppleHDAEngineInput 2>/dev/null | grep -c '"IOAudioEngineState" = 1' || echo 0)
    mic_active=$(echo "$mic_active" | tr -d '[:space:]')
    if [ "${mic_active:-0}" -gt 0 ] 2>/dev/null; then
        blocked_by="Microphone in use"
    fi
fi

if [ -n "$blocked_by" ]; then
    log "BLOCKED: $blocked_by — skipping upgrade, will retry at next scheduled slot"
    osascript -e "display notification \"Skipped due to: $blocked_by. Will retry later.\" sound name \"Glass\" with title \"hushbrew Deferred\"" 2>/dev/null || true
    exit 0
fi

# ══════════════════════════════════════════════════════════════
#  Power Status Check — Skip if battery low and not on AC
# ══════════════════════════════════════════════════════════════

# Check power source and battery level using pmset.
# Skip upgrade if battery is below 15% and not on AC power.
power_output=$(pmset -g batt 2>/dev/null || echo "")

if [ -n "$power_output" ]; then
    # Extract power source (e.g., "Now drawing from 'AC Power'")
    power_source=$(echo "$power_output" | head -1)

    # Extract battery percentage (e.g., "22%")
    battery_pct=$(echo "$power_output" | grep -o '[0-9]\+%' | head -1 | tr -d '%')

    # Check if on AC power
    on_ac=false
    if echo "$power_source" | grep -q "'AC Power'"; then
        on_ac=true
        log "INFO: On AC power — proceeding with upgrade"
    fi

    # If not on AC and battery is below 15%, skip
    if ! $on_ac && [ -n "$battery_pct" ] && [ "$battery_pct" -lt 15 ]; then
        log "BLOCKED: Battery at ${battery_pct}% (below 15%) and not on AC power — skipping upgrade"
        osascript -e "display notification \"Battery at ${battery_pct}%, need AC power or >15% battery. Will retry later.\" sound name \"Glass\" with title \"hushbrew Deferred\"" 2>/dev/null || true
        exit 0
    fi

    # If not on AC but battery is sufficient, log and proceed
    if ! $on_ac && [ -n "$battery_pct" ]; then
        log "INFO: On battery power at ${battery_pct}% (above 15%) — proceeding with upgrade"
    fi
else
    log "WARN: Unable to determine power status, proceeding anyway"
fi

# ══════════════════════════════════════════════════════════════
#  Bandwidth Detection — cap brew at 60% of current speed
# ══════════════════════════════════════════════════════════════

detect_bandwidth() {
    # Download a 2MB test payload from Cloudflare and measure speed.
    # curl reports speed_download in bytes/sec.
    local speed_bps
    speed_bps=$(/usr/bin/curl -o /dev/null -w '%{speed_download}' -m 10 -s \
        "https://speed.cloudflare.com/__down?bytes=2000000" 2>/dev/null)

    if [ -z "$speed_bps" ] || [ "$speed_bps" = "0.000" ] || [ "$speed_bps" = "0" ]; then
        log "WARN: Bandwidth detection failed, defaulting to 5MB/s limit"
        echo "5M"
        return
    fi

    # Calculate 60% of detected speed (in bytes/sec), convert to integer
    local limit
    limit=$(awk "BEGIN { printf \"%.0f\", $speed_bps * 0.6 }")

    # Floor at 1MB/s to avoid unusably slow downloads
    if [ "$limit" -lt 1048576 ]; then
        limit=1048576
    fi

    local limit_mb
    limit_mb=$(awk "BEGIN { printf \"%.1f\", $limit / 1048576 }")
    log "INFO: Detected bandwidth ~$(awk "BEGIN { printf \"%.1f\", $speed_bps / 1048576 }")MB/s, limiting brew to ${limit_mb}MB/s (60%)"

    echo "${limit}"
}

# ══════════════════════════════════════════════════════════════
#  All clear — run brew upgrade
# ══════════════════════════════════════════════════════════════

log "START: No meetings detected, beginning brew upgrade"

export PATH="$BREW_PREFIX/bin:$BREW_PREFIX/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
export HOMEBREW_NO_BOTTLE_SOURCE_FALLBACK=1
export HOMEBREW_NO_INSTALL_CLEANUP=1
export HOMEBREW_NO_ENV_HINTS=1

# Detect bandwidth and set rate limit for brew's curl
export BREW_RATE_LIMIT
BREW_RATE_LIMIT=$(detect_bandwidth)
export HOMEBREW_CURL_PATH="$HOME/.local/bin/brew-curl"

# Run with reduced CPU priority and custom timeout.
# Returns: 0 = success, 124 = timeout, other = error
run_with_timeout() {
    local secs="$1"
    shift
    nice -n 15 timeout "$secs" "$@" >> "$LOG" 2>&1
    return $?
}

# Filter a space-separated list against an exclusion list
filter_excluded() {
    local items="$1"
    local excluded_list="$2"
    local result=""
    for item in $items; do
        local skip=false
        for excluded in $excluded_list; do
            if [ "$item" = "$excluded" ]; then
                skip=true
                break
            fi
        done
        if ! $skip; then
            result="$result $item"
        fi
    done
    echo "$result" | xargs  # trim whitespace
}

# ── Step tracking ──
step_errors=""
add_error() {
    if [ -n "$step_errors" ]; then
        step_errors="$step_errors | $1"
    else
        step_errors="$1"
    fi
    log "ERROR: $1"
}

# ══════════════════════════════════════════════════════════════
#  Pre-flight Checks
# ══════════════════════════════════════════════════════════════

# Check internet connectivity
if ! /usr/bin/curl -s --max-time 5 -o /dev/null "https://formulae.brew.sh" 2>/dev/null; then
    log "ABORT: No internet connectivity"
    add_error "No internet"
    osascript -e "display notification \"No internet connection, will retry later\" sound name \"Glass\" with title \"hushbrew Skipped\"" 2>/dev/null || true
    # Don't write state file — allow retry at next slot
    exit 0
fi

# Check available disk space (need at least 1GB free)
free_space_mb=$(df -m "$BREW_PREFIX" | awk 'NR==2 {print $4}')
if [ "${free_space_mb:-0}" -lt 1024 ]; then
    log "ABORT: Low disk space (${free_space_mb}MB free, need 1024MB)"
    osascript -e "display notification \"Only ${free_space_mb}MB free, need at least 1GB\" sound name \"Glass\" with title \"hushbrew: Low Disk Space\"" 2>/dev/null || true
    exit 0
fi

# ══════════════════════════════════════════════════════════════
#  Step 1 — Update brew itself (5 min timeout)
# ══════════════════════════════════════════════════════════════

update_ok=true
run_with_timeout 300 "$BREW" update
update_exit=$?

if [ "$update_exit" -eq 124 ]; then
    add_error "brew update timed out (5 min)"
    update_ok=false
elif [ "$update_exit" -ne 0 ]; then
    add_error "brew update failed (exit $update_exit)"
    update_ok=false
fi

# ══════════════════════════════════════════════════════════════
#  Step 2 — Upgrade formulae (15 min timeout)
# ══════════════════════════════════════════════════════════════

if $update_ok; then
    outdated_formulae=$("$BREW" outdated --formula --quiet 2>/dev/null || true)

    # Apply leaves-only filtering if configured
    if [ "$UPGRADE_STRATEGY" = "leaves" ]; then
        log "INFO: Using leaves-only upgrade strategy"
        leaves=$("$BREW" leaves 2>/dev/null || true)

        # Filter outdated to only include leaves
        filtered_formulae=""
        for formula in $outdated_formulae; do
            if echo "$leaves" | grep -qw "$formula"; then
                filtered_formulae="$filtered_formulae $formula"
            fi
        done
        outdated_formulae=$(echo "$filtered_formulae" | xargs)
    fi

    formulae_to_upgrade=$(filter_excluded "$outdated_formulae" "$EXCLUDED_FORMULAE")

    if [ -n "$formulae_to_upgrade" ]; then
        if [ "$UPGRADE_STRATEGY" = "leaves" ]; then
            log "INFO: Upgrading formulae (leaves only): $formulae_to_upgrade"
        else
            log "INFO: Upgrading formulae: $formulae_to_upgrade"
        fi
        set +e  # Temporarily disable exit-on-error to capture exit code
        run_with_timeout 900 "$BREW" upgrade --formula $formulae_to_upgrade
        formula_exit=$?
        set -e  # Re-enable exit-on-error

        if [ "$formula_exit" -eq 124 ]; then
            add_error "Formula upgrade timed out (15 min)"
        elif [ "$formula_exit" -ne 0 ]; then
            add_error "Formula upgrade failed (exit $formula_exit) — may need sudo or app restart"
        fi
    else
        log "INFO: No formulae to upgrade"
    fi
fi

# ══════════════════════════════════════════════════════════════
#  Step 3 — Upgrade casks (15 min timeout)
# ══════════════════════════════════════════════════════════════

if $update_ok; then
    outdated_casks=$("$BREW" outdated --cask --greedy --quiet 2>/dev/null || true)
    casks_to_upgrade=$(filter_excluded "$outdated_casks" "$EXCLUDED_CASKS")

    if [ -n "$casks_to_upgrade" ]; then
        # Check which cask apps are currently running — they may fail to upgrade
        running_cask_apps=""
        for cask in $casks_to_upgrade; do
            app_name=$("$BREW" info --cask "$cask" 2>/dev/null | grep "\.app" | head -1 | sed 's/.*(\(.*\.app\)).*/\1/' | sed 's/\.app$//' || true)
            if [ -n "$app_name" ] && pgrep -xq "$app_name" 2>/dev/null; then
                running_cask_apps="$running_cask_apps $cask($app_name)"
            fi
        done
        if [ -n "$running_cask_apps" ]; then
            log "WARN: These apps are running and may fail to upgrade:$running_cask_apps"
        fi

        log "INFO: Upgrading casks: $casks_to_upgrade"
        set +e  # Temporarily disable exit-on-error to capture exit code
        run_with_timeout 900 "$BREW" upgrade --cask $casks_to_upgrade
        cask_exit=$?
        set -e  # Re-enable exit-on-error

        if [ "$cask_exit" -eq 124 ]; then
            add_error "Cask upgrade timed out (15 min)"
        elif [ "$cask_exit" -ne 0 ]; then
            add_error "Cask upgrade failed (exit $cask_exit) — may need sudo or app restart"
        fi
    else
        log "INFO: No casks to upgrade"
    fi
fi

# ══════════════════════════════════════════════════════════════
#  Step 4 — Cleanup (5 min timeout)
# ══════════════════════════════════════════════════════════════

run_with_timeout 300 "$BREW" cleanup --prune=7 || true

# ══════════════════════════════════════════════════════════════
#  Post-upgrade Verification
# ══════════════════════════════════════════════════════════════

notify() {
    local title="$1"
    local message="$2"
    osascript -e "display notification \"$message\" sound name \"Glass\" with title \"$title\"" 2>/dev/null || true
}

# V1. Check for formulae that are still outdated (shouldn't be)
still_outdated_formulae=$("$BREW" outdated --formula --quiet 2>/dev/null || true)
failed_formulae=$(filter_excluded "$still_outdated_formulae" "$EXCLUDED_FORMULAE")
if [ -n "$failed_formulae" ]; then
    pinned=$("$BREW" list --pinned 2>/dev/null || true)
    for f in $failed_formulae; do
        reason="unknown"
        if echo "$pinned" | grep -qw "$f"; then
            reason="pinned"
        fi
        add_error "Formula still outdated: $f ($reason)"
    done
fi

# V2. Check for casks that are still outdated (shouldn't be)
still_outdated_casks=$("$BREW" outdated --cask --greedy --quiet 2>/dev/null || true)
failed_casks=$(filter_excluded "$still_outdated_casks" "$EXCLUDED_CASKS")
if [ -n "$failed_casks" ]; then
    for c in $failed_casks; do
        reason="unknown"
        app_name=$("$BREW" info --cask "$c" 2>/dev/null | grep "\.app" | head -1 | sed 's/.*(\(.*\.app\)).*/\1/' | sed 's/\.app$//' || true)
        if [ -n "$app_name" ] && pgrep -xq "$app_name" 2>/dev/null; then
            reason="app is running"
        fi
        add_error "Cask still outdated: $c ($reason)"
    done
fi

# V3. Check for broken linkage / missing dependencies
broken_deps=$("$BREW" missing 2>/dev/null || true)
if [ -n "$broken_deps" ]; then
    add_error "Broken dependencies detected: $broken_deps"
fi

# V4. Verify disk space wasn't exhausted during upgrade
post_free_mb=$(df -m "$BREW_PREFIX" | awk 'NR==2 {print $4}')
if [ "${post_free_mb:-0}" -lt 512 ]; then
    add_error "Disk critically low after upgrade (${post_free_mb}MB free)"
fi

# ══════════════════════════════════════════════════════════════
#  Final Report + Notification
# ══════════════════════════════════════════════════════════════

if [ -n "$step_errors" ]; then
    log "DONE: hushbrew finished WITH ISSUES"
    log "ISSUES: $step_errors"

    # Truncate notification to 200 chars (macOS notification limit)
    notif_msg=$(echo "$step_errors" | cut -c1-200)
    notify "hushbrew: Issues Found" "$notif_msg"
else
    log "DONE: hushbrew finished successfully — all packages up to date"
    notify "hushbrew" "All packages updated successfully"
fi

echo "$TODAY" > "$STATE"
