# dotfiles

Every config here is symlinked into `$HOME`, so editing a dotfile in place
edits this repo. Commit and push when you're done. Works on macOS and on Arch
Linux (EndeavourOS, i3 on X11): `install.sh` links the shared configs on both
and the OS-specific ones on each.

## Fresh Mac

```sh
xcode-select --install
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
git clone git@github.com:baljinnyamday/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh --brew --tools   # symlink configs, brew bundle, then claude / uv / cursor-agent
./macos.sh                    # key repeat, dock, finder defaults
```

## Fresh Arch / EndeavourOS

```sh
sudo pacman -S --needed git github-cli yay   # yay comes from EndeavourOS's repo; on plain Arch, build it from the AUR
gh auth login
gh repo clone baljinnyamday/dotfiles ~/dotfiles
cd ~/dotfiles
./install.sh --pacman --tools   # symlink configs, Pacfile (pacman + AUR), npm globals, VS Code extensions, then claude / uv / cursor-agent
```

`Pacfile` is the Brewfile's Arch counterpart; its header lists what was swapped
or left out. The npm globals and VS Code extensions still come from the
Brewfile, so those lists stay in one place.

Both: fill in `~/.gitconfig.local` (name, email, signing key) and put any
machine-specific env, such as a work package index or tokens, in
`~/.zshrc.local`. Neither file is tracked.

## What's here

| Path | Linked to | Notes |
|---|---|---|
| `zsh/` | `~/.zshrc`, `~/.zshenv` | starship, zoxide, fzf, direnv, nvm, pnpm, bun, uv. Starts in ~0.1s: nvm loads on first use, completions rescan hourly (`rm ~/.zcompdump && reload` to force) |
| `git/` | `~/.gitconfig`, `~/.config/git/ignore`, `~/.config/git/os.gitconfig` | delta pager, zdiff3, identity from `~/.gitconfig.local`; gpg and gh paths from `os-darwin` / `os-linux.gitconfig` |
| `aerospace/` | `~/.aerospace.toml` | i3-style tiling, see keys below |
| `ghostty/` | `~/.config/ghostty/config` | Catppuccin Mocha, JetBrainsMono Nerd Font, drop-down quick terminal. cmux reads it too |
| `cmux/` | `~/.config/cmux/cmux.json` | Warp-style vertical tabs on top of Ghostty, ctrl+tab cycles the sidebar, cmd+hjkl moves between splits |
| `warp/` | `~/.warp/settings.toml` | vertical tabs, JetBrainsMono Nerd Font, Warp hot-reloads edits |
| `starship/` | `~/.config/starship.toml` | gruvbox powerline prompt |
| `tmux/` | `~/.tmux.conf` | no plugins, Catppuccin status bar on top, popups for lazygit/claude/sessions |
| `lazygit/` | `~/Library/Application Support/lazygit/config.yml`, Linux `~/.config/lazygit/config.yml` | delta diffs, Cursor as editor, claude + gh custom commands |
| `nvim/` | `~/.config/nvim` | |
| `linux/i3/` | `~/.config/i3` (Linux) | i3 + i3blocks + their scripts: AeroSpace's part, see Linux extras |
| `linux/rofi/`, `linux/dunst/` | `~/.config/rofi`, `~/.config/dunst/dunstrc` | launcher / power menu, notifications |
| `linux/xprofile`, `linux/xinitrc` | `~/.xprofile`, `~/.xinitrc` | session env read by LightDM (Qt apps follow the GTK theme); `xinitrc` only for `startx` |
| `linux/gtk/` | `~/.config/gtk-{3,4}.0/settings.ini` | Arc-Dark; nwg-look edits these through the symlinks. Dark mode itself is the `color-scheme` gsetting, set by install.sh |
| `linux/copyq/` | `~/.config/copyq/` (copied once, not linked) | CopyQ settings and commands, incl. the ctrl-shift-v menu. History stays local |
| `linux/bin/` | `~/.local/bin/` (Linux) | `pbcopy` / `pbpaste` over xclip or wl-clipboard, so every `\| pbcopy` here works unchanged; `stale` lists apps still running binaries an update replaced |
| `linux/keyd.conf` | `/etc/keyd/default.conf` (opt-in) | Caps Lock: tap Esc, hold Ctrl, see Linux extras |
| `linux/xorg-keyrepeat.conf` | `/etc/X11/xorg.conf.d/10-keyrepeat.conf` (copied with sudo) | key repeat matching `macos.sh`: 200 ms, then 60 a second |
| `bin/` | `~/.local/bin/` | every file gets linked, so a new script only needs `./install.sh`. `claude-in <folder>` (new cmux tab, or a Ghostty window outside cmux), `link-agent-docs [dir]`, `tmux-sessionizer [dir]`, plus the longer commands listed in `zsh/ALIASES.md` (`cc*` pipeline, `ship`, `wrm`, fzf pickers) |
| `Brewfile` | | refresh with `brew bundle dump --force --describe` |
| `Pacfile` | | Arch packages, `./install.sh --pacman`; lines after `[aur]` go through yay |
| `macos.sh` | | `defaults write` settings |

## Linux extras

i3 (`linux/i3/config`) plays AeroSpace's part. On top of EndeavourOS's i3 defaults:

| Key / command | Action |
|---|---|
| super-enter | Ghostty, on the current workspace (xfce4-terminal until Ghostty is installed) |
| super-w | Chrome |
| super-\` | drop-down Ghostty, an i3 scratchpad (Ghostty's own quick terminal needs Wayland) |
| ctrl-shift-v | CopyQ clipboard history (Maccy) |
| Print | flameshot: select an area, annotate, copy or save |
| `sysup` | `yay -Syu`, remove orphans, then `stale` |
| `stale` | apps still running replaced binaries: restart them, or reboot after big updates |
| `caff [cmd]` | keep the machine awake (`systemd-inhibit`) |

Opt-in, both need root:

```sh
# Caps Lock: tap for Esc, hold for Ctrl, in every app and the TTY
sudo install -Dm644 linux/keyd.conf /etc/keyd/default.conf && sudo systemctl enable --now keyd
# compressed swap in RAM (macOS compresses memory by default; without it a runaway build freezes the box)
sudo pacman -S zram-generator && printf '[zram0]\nzram-size = ram / 4\n' | sudo tee /etc/systemd/zram-generator.conf \
  && sudo systemctl daemon-reload && sudo systemctl start systemd-zram-setup@zram0
```

**Per machine, not in the repo:** `~/.gitconfig.local`, `~/.zshrc.local`, the wallpaper
(`~/Desktop/mt1.jpg`), the monitor layout `~/.screenlayout/monitor.sh` (make it with arandr), and the
mouse name in the `xinput` line of `linux/i3/config` (`xinput list` shows yours).

**Updating EndeavourOS** (learned the hard way on a year-old install):

- After a big `sysup`, run `stale` and restart what it lists, or reboot. An app still running its old
  binary can break against the new one: CopyQ's ctrl-shift-v menu hung until it was restarted.
- Don't blindly accept these `.pacnew` files, they'd drop local setup: `pacman.conf` ([endeavouros] and
  [multilib] repos), `locale.gen` (en_US, mn_MN), `lightdm.conf` (i3 session, autologin), `hosts`.
  Merge by hand instead of `pacdiff`.
- Read the AUR diff before building; the AUR has had malicious uploads. `slack` there is an unrelated
  CLI: the app is `slack-desktop`.

## AeroSpace keys

`alt` is the modifier.

| Key | Action |
|---|---|
| alt-enter | open cmux |
| alt-shift-enter | new Ghostty window |
| alt-h / j / k / l | focus window (wraps around) |
| alt-shift-h / j / k / l | move window |
| ctrl-alt-h / j / k / l | focus monitor |
| ctrl-alt-shift-h / l | move window to monitor |
| alt-1 … 9, alt-0 | workspace 1 … 9, 0 |
| alt-shift-1 … 0 | move window to workspace |
| alt-tab | previous workspace |
| alt-shift-tab | move workspace to next monitor |
| alt-n / c / s / t / o / w / e | Notion / Claude / Slack / Teams / Outlook / cmux / Cursor workspace, launches the app |
| alt-shift-n / c / s / t / o / w / e | move window to that app's workspace |
| alt-b | open Chrome |
| alt-f | fullscreen |
| alt-shift-space | toggle floating |
| alt-slash, alt-comma | tiles / accordion layout |
| alt-minus, alt-equal | shrink / grow |
| alt-r | resize mode: h/j/k/l, `=` balances, esc |
| alt-shift-q | close window |
| alt-shift-r | reload config |
| alt-shift-; | service mode: r flatten, f float, backspace close others, alt-shift-hjkl join |

## Terminal keys

**cmux** (vertical tabs, reads the Ghostty config)

| Key | Action |
|---|---|
| cmd-1 … 9 | jump to sidebar tab |
| ctrl-tab / ctrl-shift-tab | next / previous sidebar tab |
| cmd-n | new sidebar tab (workspace) |
| cmd-t | new tab inside the workspace |
| cmd-b | show / hide sidebar |
| cmd-shift-r | rename workspace |
| cmd-d / cmd-shift-d | split right / down |
| cmd-h / j / k / l | move between splits (only when the workspace is split, so cmd-h hide / cmd-k clear still work) |
| cmd-shift-enter | zoom split |
| cmd-shift-u | jump to the agent waiting for you |
| ctrl-cmd-shift-d | diff viewer |
| cmd-shift-w | close workspace |

**Ghostty** (horizontal native tabs; under AeroSpace each tab leaves an empty gap, [AeroSpace#68](https://github.com/nikitabobko/AeroSpace/issues/68), so prefer cmux or new windows)

| Key | Action |
|---|---|
| cmd-1 … 8, cmd-9 | jump to tab, last tab |
| ctrl-tab / ctrl-shift-tab | next / previous tab |
| cmd-shift-left / right | move tab |
| cmd-shift-r | rename tab |
| cmd-d / cmd-shift-d | split right / down |
| cmd-alt-arrows | move between splits |
| cmd-shift-enter | zoom split |
| ctrl-\` (anywhere) | drop-down quick terminal |

**tmux** (prefix is ctrl-b). For SSH and the plain-Ghostty fallback; inside cmux use workspaces and splits instead, see `zsh/ALIASES.md`

| Key | Action |
|---|---|
| prefix f | fzf session picker (`ts` outside cmux and tmux) |
| prefix w / s | tree of windows / sessions with preview |
| prefix g / C / t | popup lazygit / claude / scratch shell |
| prefix \| / - | split right / down in current folder |
| prefix h j k l, H J K L | move / resize panes (repeatable) |
| prefix tab, shift-tab | last window, last session |
| prefix < / > | move window left / right |
| prefix v | copy mode: v select, ctrl-v block, y copy |
| prefix X | kill session |
| prefix r | reload config |

**lazygit** extras (press `?` for everything)

| Where | Key | Action |
|---|---|---|
| files | ctrl-g | claude drafts the commit message, you edit it |
| branches | ctrl-v | claude reviews branch vs main |
| commits | ctrl-x | claude explains the commit |
| branches | S | push and open PR |
| branches | ctrl-n | check out an open PR |
| branches | D | delete branches merged into main |
| diff | \| | cycle delta / side-by-side |
