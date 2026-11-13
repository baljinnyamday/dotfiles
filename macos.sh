#!/usr/bin/env bash
# macOS defaults. Run once on a new machine; log out and back in for the
# keyboard settings to take effect.
set -euo pipefail

# Apple doesn't document the unit; linux/xorg-keyrepeat.conf reads it as 1/60 s ticks (250 ms, then 60/s).
defaults write -g KeyRepeat -int 1
defaults write -g InitialKeyRepeat -int 15
# § ± types ` ~. Copied, not linked: launchd skips symlinked agents at login on some macOS versions.
agent="$HOME/Library/LaunchAgents/com.dotfiles.keyremap.plist"
install -m644 "$(dirname "$0")/macos/keyremap.plist" "$agent"
launchctl bootout "gui/$(id -u)/com.dotfiles.keyremap" 2>/dev/null || true # not loaded on the first run
launchctl bootstrap "gui/$(id -u)" "$agent"

defaults write com.apple.dock autohide -bool true
defaults write com.apple.finder ShowPathbar -bool true

killall Dock Finder
echo "done."
