# ~/dotfiles/zsh/aliases.zsh -- sourced from .zshrc
# Only aliases, one-liners, and functions that must change this shell (cd / export) live here.
# Anything longer is a script in ../bin (linked into ~/.local/bin by install.sh), so it also
# works from bash, other scripts, tmux/cmux keybindings and agents.

# --- OS ---
# pbcopy/pbpaste work on both: on Linux they're scripts in ../linux/bin over xclip / wl-clipboard.
if [[ $OSTYPE == darwin* ]]; then
  alias flushdns='sudo dscacheutil -flushcache && sudo killall -HUP mDNSResponder'
  alias o='open .'
  alias ql='qlmanage -p &>/dev/null'
  alias ip='ipconfig getifaddr en0'
  alias dsclean='fd -H -I "^\.DS_Store$" -x rm'
  alias brewup='brew update && brew upgrade && brew cleanup && brew doctor'
else
  alias ls='ls --color=auto'
  alias o='xdg-open . &>/dev/null &!'
  alias lanip='ip -4 -o route get 1.1.1.1 | awk "{print \$7}"'   # `ip` itself stays iproute2
  # sysup: upgrade repo + AUR packages, drop orphans, then list apps still running replaced binaries
  alias sysup='yay -Syu && yay -Yc && stale'
fi
alias pubip='curl -s ifconfig.me && echo'
alias cpwd='pwd | tr -d "\n" | pbcopy'

# --- dev workflow ---
# killport [-f] <port>: TERM whatever is listening on the port so it can shut down cleanly;
# names it after a second if it's still up. -f sends KILL instead.
killport() {
  local sig=TERM; [[ $1 == -f ]] && { sig=KILL; shift; }
  local pids; pids=$(lsof -ti tcp:"$1" -sTCP:LISTEN) || { echo "killport: nothing listening on ${1:-?}" >&2; return 1; }
  kill -s $sig ${=pids}
  [[ $sig == TERM ]] || return 0
  sleep 1
  local pid; for pid in ${=pids}; do kill -0 $pid 2>/dev/null && echo "$pid still running, use killport -f $1" >&2; done
  return 0
}
port()     { lsof -nP -iTCP:"$1" -sTCP:LISTEN; }
alias listening='lsof -nP -iTCP -sTCP:LISTEN'
alias json='pbpaste | jq .'
alias jsonc='pbpaste | jq -c . | pbcopy'

# --- docker / package managers ---
alias dps='docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"'
alias dpsa='docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Image}}"'
alias dcu='docker compose up -d'
alias dcd='docker compose down'
alias dcl='docker compose logs -f --tail 100'
alias pnr='pnpm run'

# --- terminals: cmux is the main one, Ghostty is the lightweight fallback ---
if [[ $OSTYPE == darwin* ]]; then
  alias ghost='open -na Ghostty --args --working-directory="$PWD"'   # plain Ghostty window in this folder
else
  alias ghost='ghostty --working-directory="$PWD" &>/dev/null &!'
fi

# --- project switching: cmux workspaces inside cmux, tmux sessions elsewhere ---
alias ts='sessionizer'                           # fzf-pick a project, jump to its workspace/session

# --- tmux: for SSH and the plain-Ghostty fallback. Inside cmux use workspaces/splits instead ---
alias ta='tmux attach 2>/dev/null || tmux new -s main'
alias tl='tmux ls'

# --- claude code (headless / -p; ccf is a script in ../bin) ---
ccmsg()  { git diff --staged | claude -p "write a concise conventional-commit message for this diff, one line under 72 chars, no body unless truly needed"; }
ccpr()   { git diff main...HEAD | claude -p "review this diff for bugs; be terse"; }
ccx()    { claude -p "explain @$1 concisely"; }
ccj()    { claude -p "$1" --output-format json | jq -r '.result'; }

# ?? <what you want>: Claude writes one shell command and puts it on your prompt line, unrun.
# Enter runs it, Ctrl-C drops it, or edit first. noglob keeps `*.ts` and a trailing `?` literal.
alias '??'='noglob ccsh'
ccsh() {
  local cmd os="macOS with Homebrew"
  [[ $OSTYPE == darwin* ]] || os="$(. /etc/os-release && echo "$PRETTY_NAME") with pacman/yay${XDG_CURRENT_DESKTOP:+, $XDG_CURRENT_DESKTOP on $XDG_SESSION_TYPE}"
  cmd=$(claude -p --tools "" --no-session-persistence --output-format text \
    --system-prompt "You write zsh one-liners for $os. Prefer rg, fd, eza, bat, sd, jq, yq when they fit. Reply with the command only: no backticks, no explanation." \
    "$*" </dev/null) || return 1
  print -z -- "$cmd"
}

# --- claude code: opsx plan -> review -> apply pipeline, and small tasks ---
# ccplan, ccreview, ccapply, ccdo, ccdoh are scripts in ../bin

# --- claude code: switch which account/config-dir all cc* aliases use (this shell only) ---
ccas() {
  local -a dirs=(~/.claude ~/.ccw ~/.claude-*(N))
  local sel; sel=$(printf '%s\n' "${dirs[@]}" | fzf --print-query --prompt='claude account> ' | tail -1)
  [[ -z "$sel" ]] && return
  [[ "$sel" != /* ]] && sel="$HOME/.claude-$sel"
  if [[ "$sel" == "$HOME/.claude" ]]; then unset CLAUDE_CONFIG_DIR; else export CLAUDE_CONFIG_DIR="$sel"; fi
  echo "claude account: ${CLAUDE_CONFIG_DIR:-default}"
}

# --- branch / worktree create + merge-back (ship, wrm are scripts in ../bin) ---
cbn() { git checkout -b "$1"; }
wt() { git worktree add "../$1" -b "$1" "${2:-HEAD}" && cd "../$1"; }  # wt <name> [base], base defaults to current HEAD
wcd() { cd "$(git worktree list | fzf --prompt='worktree> ' | awk '{print $1}')"; }
# wca <name> [base]: wt for a folder of sibling repos (e.g. ~/coding/bagsh holding bagsh.back +
# bagsh.space): one worktree per repo in ../<folder>-wt/<name>/<repo>, all on branch <name>, then
# cds into that feature folder. Run it from the parent folder; base defaults to each repo's HEAD.
wca() {
  [[ -n $1 ]] || { echo "usage: wca <name> [base]" >&2; return 1; }
  local dest=${PWD:h}/${PWD:t}-wt/$1 repo
  local -a repos=(*/.git(N:h))
  (( $#repos )) || { echo "wca: no git repos directly below $PWD" >&2; return 1; }
  for repo in $repos; do
    git -C "$repo" worktree add "$dest/$repo" -b "$1" "${2:-HEAD}" || return 1
  done
  cd "$dest"
}

# --- fzf pickers (frg, ff, fbr, fkill, dsh are scripts in ../bin) ---
fcd() { cd "$(fd -t d | fzf)"; }   # fzf-pick any folder below this one and cd into it

# --- yazi: y opens the file manager; quitting with q leaves this shell in the folder you were in ---
y() {
  local tmp cwd
  tmp=$(mktemp -t yazi-cwd.XXXXXX)
  yazi "$@" --cwd-file="$tmp"
  cwd=$(<"$tmp")
  [[ -n $cwd && $cwd != "$PWD" ]] && builtin cd -- "$cwd"
  rm -f -- "$tmp"
}

# --- zsh: global + suffix aliases ---
alias -g G='| grep -i'
alias -g C='| pbcopy'   # copy output to the clipboard: pwd C
alias -g J='| jq .'     # pretty-print JSON output: curl -s localhost:3000/api J
alias -s {json,yaml,yml,toml,md,txt}=bat
alias -s {ts,tsx,js,py,go,rs}=cursor
