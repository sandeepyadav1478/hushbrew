# typed: false
# frozen_string_literal: true

# Formula for hushbrew - Automatic daily Homebrew upgrades for macOS
class Hushbrew < Formula
  desc "Automatic daily Homebrew upgrades for macOS that stay out of your way"
  homepage "https://github.com/sandeepyadav1478/homebrew-hushbrew"
  url "https://github.com/sandeepyadav1478/homebrew-hushbrew/archive/refs/tags/v1.0.3.tar.gz"
  sha256 "c86a12d6b98484a070fa9b54bad39295d5c6b5e267faaac740ef4c97c2e60d23"
  license "MIT"
  head "https://github.com/sandeepyadav1478/homebrew-hushbrew.git", branch: "main"

  # hushbrew requires GNU timeout from coreutils
  depends_on "coreutils"

  def install
    # Install scripts to libexec
    libexec.install "bin/hushbrew.sh"
    libexec.install "bin/brew-curl"
    libexec.install "bin/hushbrew-setup"

    # Store the plist template
    (libexec/"launchd").mkpath
    (libexec/"launchd").install "launchd/com.local.hushbrew.plist"

    # Install main hushbrew command
    bin.install "bin/hushbrew"
  end

  def caveats
    <<~EOS
      To start hushbrew, run:
        hushbrew start

      This will set up and start automatic Homebrew upgrades.
      Runs at 10 AM, 2 PM, and 6 PM daily.

      Other commands:
        hushbrew stop     - Stop the service
        hushbrew status   - Show status
        hushbrew logs     - View logs
        hushbrew run      - Run upgrade manually
        hushbrew help     - Show all commands

      Features:
        • Meeting-aware (Zoom, Slack, mic detection)
        • Power-aware (skips if battery <15%)
        • Bandwidth throttling (60% of detected speed)

      Configuration:
        ~/.config/hushbrew/config
    EOS
  end

  service do
    run opt_libexec/"hushbrew.sh"
    working_dir Dir.home
    keep_alive false
  end

  def post_uninstall
    # Stop and unload the LaunchAgent
    quiet_system "launchctl", "bootout", "gui/#{Process.uid}/com.local.hushbrew"
  end

  def zap
    # Remove user files
    rm_f [
      "#{Dir.home}/.local/bin/hushbrew.sh",
      "#{Dir.home}/.local/bin/brew-curl",
      "#{Dir.home}/.local/log/hushbrew.log",
      "#{Dir.home}/.local/log/hushbrew.log.old",
      "#{Dir.home}/.local/log/hushbrew.lastrun",
      "#{Dir.home}/Library/LaunchAgents/com.local.hushbrew.plist",
    ]

    # Remove config directory
    rm_rf "#{Dir.home}/.config/hushbrew"

    # Try to remove directories if empty
    rmdir ["#{Dir.home}/.local/log", "#{Dir.home}/.local/bin"].select { |d| File.directory?(d) && Dir.empty?(d) }

    # Remove lock file
    rmdir "/tmp/hushbrew.lock" if File.directory?("/tmp/hushbrew.lock")
  end

  test do
    # Test that scripts have valid syntax
    system "bash", "-n", opt_libexec/"hushbrew.sh"
    system "bash", "-n", opt_libexec/"brew-curl"

    # Verify plist template exists
    assert_predicate opt_libexec/"launchd/com.local.hushbrew.plist", :exist?

    # Verify plist has expected content
    plist_content = (opt_libexec/"launchd/com.local.hushbrew.plist").read
    assert_match "__HOME__", plist_content
    assert_match "StartCalendarInterval", plist_content
  end
end
