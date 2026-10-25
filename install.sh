#!/usr/bin/env bash
# Symlinks every config in this repo into $HOME. Safe to re-run. Works on macOS and Arch Linux.
#   ./install.sh           symlink configs
#   ./install.sh --brew    macOS: also install everything in the Brewfile
#   ./install.sh --pacman  Arch: also install everything in the Pacfile, plus the Brewfile's npm
#                          globals and VS Code extensions (what `brew bundle` covers on macOS)
#   ./install.sh --tools   also install CLIs that ship their own installer (claude, uv, cursor-agent)
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OS="$(uname -s)"

BREW=0 PACMAN=0 TOOLS=0
for arg in "$@"; do
  case "$arg" in
    --brew)   BREW=1 ;;
    --pacman) PACMAN=1 ;;
    --tools)  TOOLS=1 ;;
    *) echo "usage: ./install.sh [--brew | --pacman] [--tools]" >&2; exit 1 ;;
  esac
done

link() {
  local src="$REPO/$1" dest="$HOME/$2"
  mkdir -p "$(dirname "$dest")"
  if [ -e "$dest" ] && [ ! -L "$dest" ]; then
    mv "$dest" "$dest.bak.$(date +%Y%m%d%H%M%S)"
    echo "backed up ~/$2"
  fi
  ln -sfn "$src" "$dest"
  echo "linked    ~/$2"
}

link zsh/.zshrc               .zshrc
link zsh/.zshenv              .zshenv
link git/.gitconfig           .gitconfig
link git/ignore               .config/git/ignore
link ghostty/config           .config/ghostty/config
link starship/starship.toml   .config/starship.toml
link tmux/.tmux.conf          .tmux.conf
link nvim                     .config/nvim
for script in "$REPO"/bin/*; do
  link "bin/${script##*/}" ".local/bin/${script##*/}"
done

if [ "$OS" = Darwin ]; then
  link git/os-darwin.gitconfig  .config/git/os.gitconfig
  link aerospace/aerospace.toml .aerospace.toml
  link cmux/cmux.json           .config/cmux/cmux.json
  link lazygit/config.yml       "Library/Application Support/lazygit/config.yml"
  link warp/settings.toml       .warp/settings.toml
else
  link git/os-linux.gitconfig   .config/git/os.gitconfig
  link lazygit/config.yml       .config/lazygit/config.yml
  # The i3 desktop: AeroSpace's counterpart, plus its launcher, notifications and session env
  link linux/i3                 .config/i3
  link linux/rofi               .config/rofi
  link linux/dunst/dunstrc      .config/dunst/dunstrc
  link linux/xprofile           .xprofile
  link linux/xinitrc            .xinitrc
  link linux/gtk/gtk-3.0-settings.ini .config/gtk-3.0/settings.ini
  link linux/gtk/gtk-4.0-settings.ini .config/gtk-4.0/settings.ini
  # CopyQ rewrites its config by replacing the file, which would turn a symlink into a plain copy,
  # so it's seeded once instead: the Ctrl+Shift+V history menu and the other commands.
  for f in copyq.conf copyq-commands.ini; do
    if [ ! -e "$HOME/.config/copyq/$f" ]; then
      install -Dm644 "$REPO/linux/copyq/$f" "$HOME/.config/copyq/$f" && echo "copied    ~/.config/copyq/$f"
    fi
  done
  # pbcopy/pbpaste stand-ins and other Linux-only scripts
  for script in "$REPO"/linux/bin/*; do
    link "linux/bin/${script##*/}" ".local/bin/${script##*/}"
  done
  # Dark mode. Without a desktop environment nothing sets this, and Firefox and GTK4 apps read
  # "no preference" from the desktop portal as light, whatever the GTK theme is.
  if command -v gsettings >/dev/null; then
    gsettings set org.gnome.desktop.interface color-scheme prefer-dark && echo "set       dark mode (color-scheme)"
  fi
  # Key repeat matching macos.sh. X reads its config only from /etc, so this one is copied with sudo,
  # and only when it changed; it takes effect at the next login.
  keyrepeat=/etc/X11/xorg.conf.d/10-keyrepeat.conf
  if ! cmp -s "$REPO/linux/xorg-keyrepeat.conf" "$keyrepeat"; then
    sudo install -Dm644 "$REPO/linux/xorg-keyrepeat.conf" "$keyrepeat" && echo "installed $keyrepeat (log out and back in)" \
      || echo "skipped   $keyrepeat (needs sudo)"
  fi
fi

if [ ! -f "$HOME/.gitconfig.local" ]; then
  printf '[user]\n\tname = Your Name\n\temail = you@example.com\n' > "$HOME/.gitconfig.local"
  echo "created   ~/.gitconfig.local -- put your git identity there"
fi

if [ "$BREW" = 1 ]; then
  brew bundle --file="$REPO/Brewfile"
fi

if [ "$PACMAN" = 1 ]; then
  # Pacfile: one package per line; lines after [aur] come from the AUR through yay.
  pkgs() { sed 's/#.*//' "$REPO/Pacfile" | awk -v want="$1" '/^\[aur\]/ {aur=1; next} NF && aur==want {print $1}'; }
  official=() aur=()
  while read -r p; do official+=("$p"); done < <(pkgs 0)
  while read -r p; do aur+=("$p"); done < <(pkgs 1)
  sudo pacman -S --needed "${official[@]}"
  # --needed leaves a package that was already pulled in as a dependency marked as one, so an
  # orphan cleanup (`yay -Yc`, part of sysup) would remove it once nothing depends on it.
  sudo pacman -D --asexplicit --quiet "${official[@]}"
  if command -v yay >/dev/null; then
    yay -S --needed "${aur[@]}"
    sudo pacman -D --asexplicit --quiet "${aur[@]}"
  else
    echo "skipped AUR packages (install yay first): ${aur[*]}"
  fi
  # The rest of the Brewfile: npm globals and VS Code extensions. npm needs a Node it can write to
  # (nvm's), not the system one in /usr.
  if command -v npm >/dev/null && [ -w "$(npm config get prefix)" ]; then
    npm install -g $(sed -n 's/^npm "\(.*\)"/\1/p' "$REPO/Brewfile") || echo "some npm installs failed; see above"
  else
    echo "skipped npm globals: no npm with a writable prefix (install Node with nvm, then re-run)"
  fi
  if command -v code >/dev/null; then
    sed -n 's/^vscode "\(.*\)"/\1/p' "$REPO/Brewfile" | while read -r ext; do
      code --install-extension "$ext" >/dev/null 2>&1 || echo "failed:   VS Code extension $ext"
    done
  fi
fi

# Not in the Brewfile/Pacfile because they self-update through their own installers.
# All of them land in ~/.local/bin, which .zshrc already puts on PATH.
tool() {
  if command -v "$1" >/dev/null || [ -x "$HOME/.local/bin/$1" ]; then
    echo "have      $1"
  else
    echo "installing $1"
    bash -c "$2"
  fi
}

if [ "$TOOLS" = 1 ]; then
  tool claude       'curl -fsSL https://claude.ai/install.sh | bash'
  tool uv           'curl -LsSf https://astral.sh/uv/install.sh | env UV_NO_MODIFY_PATH=1 sh'
  tool cursor-agent 'curl -fsS https://cursor.com/install | bash'
fi

echo "done."
