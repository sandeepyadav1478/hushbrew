# typed: false
# frozen_string_literal: true

# Formula for hushbrew - Automatic daily Homebrew upgrades for macOS
class Hushbrew < Formula
  desc "Automatic daily Homebrew upgrades for macOS that stay out of your way"
  homepage "https://github.com/sandeepyadav1478/hushbrew"
  url "https://github.com/sandeepyadav1478/hushbrew/archive/refs/tags/v1.0.0.tar.gz"
  sha256 "YOUR_SHA256_CHECKSUM_HERE"
  license "MIT"
  head "https://github.com/sandeepyadav1478/hushbrew.git", branch: "main"

  # hushbrew requires GNU timeout from coreutils
  depends_on "coreutils"

  def install
    # Install scripts to libexec (they'll be set up in post_install)
    libexec.install "bin/hushbrew.sh"
    libexec.install "bin/brew-curl"

    # Store the plist template
    (libexec/"launchd").mkpath
    (libexec/"launchd").install "launchd/com.local.hushbrew.plist"
  end

  def post_install
    # Create necessary directories
    bin_dir = Pathname.new(Dir.home)/".local/bin"
    log_dir = Pathname.new(Dir.home)/".local/log"
    config_dir = Pathname.new(Dir.home)/".config/hushbrew"
    plist_dir = Pathname.new(Dir.home)/"Library/LaunchAgents"

    [bin_dir, log_dir, config_dir, plist_dir].each(&:mkpath)

    # Install scripts
    (bin_dir/"hushbrew.sh").write (libexec/"hushbrew.sh").read
    (bin_dir/"brew-curl").write (libexec/"brew-curl").read

    # Make scripts executable
    (bin_dir/"hushbrew.sh").chmod 0755
    (bin_dir/"brew-curl").chmod 0755

    # Create default config if it doesn't exist
    config_file = config_dir/"config"
    unless config_file.exist?
      config_file.write <<~EOS
        # hushbrew configuration
        #
        # Exclusion lists — space-separated package names that should NOT be auto-upgraded.
        # Example: EXCLUDED_FORMULAE="node python@3.11"

        EXCLUDED_FORMULAE=""
        EXCLUDED_CASKS=""
      EOS
      ohai "Created default config at #{config_file}"
    end

    # Generate plist from template
    plist_content = (libexec/"launchd/com.local.hushbrew.plist").read
    plist_content.gsub!("__HOME__", Dir.home)
    plist_file = plist_dir/"com.local.hushbrew.plist"
    plist_file.write plist_content

    ohai "hushbrew installed successfully!"
    ohai "Scripts installed to #{bin_dir}"
    ohai "LaunchAgent plist created at #{plist_file}"
  end

  def caveats
    <<~EOS
      hushbrew has been installed but not yet activated.

      To start hushbrew (runs at 10 AM, 2 PM, 6 PM daily):
        brew services start hushbrew

      Or load manually with launchctl:
        launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.local.hushbrew.plist

      Configuration:
        Edit ~/.config/hushbrew/config to exclude packages from auto-upgrade

      Logs:
        tail -f ~/.local/log/hushbrew.log

      Run manually for testing:
        ~/.local/bin/hushbrew.sh

      To stop hushbrew:
        brew services stop hushbrew

      Features:
        • Meeting-aware (Zoom, Slack, mic detection)
        • Power-aware (skips if battery <15%)
        • Bandwidth throttling (60% of detected speed)
        • Once-daily with automatic retries
    EOS
  end

  service do
    run opt_libexec/"hushbrew.sh"
    working_dir Dir.home
    keep_alive false
    # Use the calendar-based scheduling from our plist
    # brew services will use the plist we installed
    plist_options manual: "launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.local.hushbrew.plist"
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
