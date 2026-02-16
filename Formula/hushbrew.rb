# typed: false
# frozen_string_literal: true

# Formula for hushbrew - Automatic daily Homebrew upgrades for macOS
class Hushbrew < Formula
  desc "Automatic daily Homebrew upgrades for macOS that stay out of your way"
  homepage "https://github.com/sandeepyadav1478/hushbrew"
  url "https://github.com/sandeepyadav1478/hushbrew/archive/refs/tags/v1.0.0.tar.gz"
  sha256 "d615401d477c9e9e96f9813f77f07ffb31f61ba48f5ee2dcd527cd056934173e"
  license "MIT"
  head "https://github.com/sandeepyadav1478/hushbrew.git", branch: "main"

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

    # Create a wrapper script that users can call
    (bin/"hushbrew-setup").write <<~EOS
      #!/bin/bash
      exec "#{libexec}/hushbrew-setup" "$@"
    EOS
  end

  def caveats
    <<~EOS
      To complete installation, run the setup script:
        hushbrew-setup

      This will:
        • Copy scripts to ~/.local/bin/
        • Create config at ~/.config/hushbrew/config
        • Install LaunchAgent plist

      Then start hushbrew:
        brew services start hushbrew

      Or load manually:
        launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.local.hushbrew.plist

      Features:
        • Runs at 10 AM, 2 PM, 6 PM daily
        • Meeting-aware (Zoom, Slack, mic detection)
        • Power-aware (skips if battery <15%)
        • Bandwidth throttling (60% of detected speed)
        • Once-daily with automatic retries

      Configuration:
        Edit ~/.config/hushbrew/config to exclude packages

      Logs:
        tail -f ~/.local/log/hushbrew.log

      Manual run:
        ~/.local/bin/hushbrew.sh
    EOS
  end

  service do
    run opt_libexec/"hushbrew.sh"
    working_dir Dir.home
    keep_alive false
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
