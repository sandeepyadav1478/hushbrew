# GitHub Repository Setup Guide

Complete guide for creating a professional hushbrew repository on GitHub.

## Quick Start

1. Go to: https://github.com/new
2. Use the information below
3. After creation, run: `git push -u origin main`

---

## Basic Repository Information

**Repository name:**
```
hushbrew
```

**Description:**
```
🤫 Automatic daily Homebrew upgrades for macOS that stay out of your way
```

**Settings:**
- ✅ Public
- ❌ DO NOT add README (we have one)
- ❌ DO NOT add .gitignore (we have one)
- ❌ DO NOT add license (we have MIT)

---

## Topics for Discoverability

Add these topics (Settings → About → Topics):

```
homebrew, macos, automation, brew, homebrew-tap, launchagent, auto-update, meeting-aware, bandwidth-throttling, power-aware, shell-script, bash
```

---

## Repository Description (About Section)

Click the ⚙️ gear icon next to "About":

**Description:**
```
🤫 Automatic daily Homebrew upgrades for macOS that stay out of your way
```

**Website:** (leave empty or add personal site)

**Topics:** Same as above

**Include in home page:**
- ✅ Releases
- ✅ Packages

---

## Features to Enable

Go to: Settings → General → Features

- ✅ Issues
- ✅ Preserve this repository
- ❌ Sponsorships (optional)
- ❌ Discussions (optional)
- ✅ Projects (optional)
- ✅ Wiki (optional)

---

## Security Settings

Go to: Settings → Security → Code security and analysis

- ✅ Dependency graph
- ✅ Dependabot alerts
- ✅ Dependabot security updates
- ✅ Secret scanning

---

## Branch Protection Rules

Go to: Settings → Branches → Add branch protection rule

**Branch name pattern:** `main`

**Rules:**
- ✅ Require a pull request before merging
- ✅ Require status checks to pass (select "CI" after first workflow run)
- ✅ Require conversation resolution before merging
- ✅ Include administrators

---

## Recommended Badges for README

Add these at the top of README.md after pushing:

```markdown
[![CI](https://github.com/sandeepyadav1478/hushbrew/actions/workflows/ci.yml/badge.svg)](https://github.com/sandeepyadav1478/hushbrew/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![macOS](https://img.shields.io/badge/macOS-11.0%2B-blue)](https://www.apple.com/macos/)
[![Homebrew](https://img.shields.io/badge/Homebrew-required-orange.svg)](https://brew.sh)
[![GitHub release](https://img.shields.io/github/v/release/sandeepyadav1478/hushbrew)](https://github.com/sandeepyadav1478/hushbrew/releases)
[![GitHub stars](https://img.shields.io/github/stars/sandeepyadav1478/hushbrew?style=social)](https://github.com/sandeepyadav1478/hushbrew/stargazers)
```

---

## Custom Issue Labels

Go to: Issues → Labels

Add these custom labels:

- `meeting-detection` (color: #0075ca) - Meeting detection issues
- `power-management` (color: #0e8a16) - Battery/AC power related
- `bandwidth` (color: #1d76db) - Bandwidth throttling related
- `formula` (color: #d93f0b) - Homebrew formula issues
- `macos-specific` (color: #5319e7) - macOS-specific issues

---

## Release Template (v1.0.0)

After pushing code, create a release:

**Tag:** `v1.0.0`

**Title:** `v1.0.0 - Initial Release`

**Description:**
```markdown
## 🎉 Initial Release of hushbrew

hushbrew is now available! Install with:
```bash
brew install sandeepyadav1478/hushbrew/hushbrew
brew services start hushbrew
```

### ✨ Features
- 🤫 Meeting-aware (Zoom, Slack, microphone detection)
- 🔋 Power-aware (skips if battery <15%)
- 🌐 Bandwidth throttling (60% of detected speed)
- 📅 Once-daily with automatic retries (10 AM, 2 PM, 6 PM)
- 🎯 Package exclusion lists
- 🔒 Safe with timeouts, locks, and verification
- 📊 Detailed logging and notifications

### 📦 What's Included
- Main upgrade script with all smart features
- Bandwidth-limiting curl wrapper
- LaunchAgent for automatic scheduling
- Homebrew formula for easy installation
- Complete documentation

### 🚀 Quick Start
See the [README](https://github.com/sandeepyadav1478/hushbrew#readme)
for installation and configuration instructions.

### 🙏 Feedback
Please report bugs and suggest features via
[Issues](https://github.com/sandeepyadav1478/hushbrew/issues).
```

---

## Social Preview Image (Optional)

Go to: Settings → General → Social preview

Create a 1280×640px image with:
- Project name: "hushbrew"
- Tagline: "Automatic Homebrew upgrades that stay out of your way"
- Key features: 🤫 🍺 ⚡ 🔋

Or use: https://og-image.vercel.app/

Example text:
```
hushbrew
🤫 Automatic Homebrew upgrades for macOS
Meeting-aware • Power-aware • Bandwidth-throttling
```

---

## Optional: GitHub Pages

Go to: Settings → Pages

- Source: Deploy from a branch
- Branch: main / docs

Site URL: https://sandeepyadav1478.github.io/hushbrew/

---

## Community Files (Already Included ✅)

Your repository already includes:
- ✅ CODE_OF_CONDUCT.md
- ✅ CONTRIBUTING.md
- ✅ LICENSE (MIT)
- ✅ SECURITY.md
- ✅ .github/ISSUE_TEMPLATE/
- ✅ .github/PULL_REQUEST_TEMPLATE.md
- ✅ .github/workflows/ci.yml

These automatically show in: Insights → Community

---

## Complete SEO-Optimized Description

For external sharing, documentation, or website:

```
hushbrew is an intelligent LaunchAgent for macOS that automatically keeps
your Homebrew packages up-to-date without interrupting your work.

Key Features:
• 🤫 Meeting-aware: Detects Zoom calls, Slack huddles, and active microphone
• 🔋 Power-aware: Skips upgrades when battery is below 15%
• 🌐 Bandwidth-throttling: Caps downloads at 60% of detected speed
• 🔒 Safe: Lock files, timeouts, disk space checks, verification
• 📅 Once-daily: Runs at 10 AM, 2 PM, 6 PM with automatic retries
• 🎯 Configurable: Exclude specific packages from auto-upgrade
• 📊 Observable: Detailed logs and macOS notifications
• 🚀 Easy install: One-line Homebrew installation

Unlike other auto-update tools, hushbrew is designed to be completely
invisible during your work. It intelligently detects when you're busy
(in meetings, on battery, low bandwidth) and defers upgrades until a
better time.

Perfect for:
- Developers who want packages always current without manual intervention
- MacBook users who work unplugged frequently
- Remote workers in video calls throughout the day
- Teams who need consistent, automated package management
```

---

## Next Steps After Creating Repository

1. ✅ Create repository on GitHub
2. `git push -u origin main`
3. `git tag -a v1.0.0 -m "Release version 1.0.0"`
4. `git push origin v1.0.0`
5. Generate SHA256 and update formula
6. Configure repository settings (topics, security, etc.)
7. Create v1.0.0 release on GitHub
8. Test: `brew install sandeepyadav1478/hushbrew/hushbrew`
