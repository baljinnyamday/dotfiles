# ~/.zshenv -- symlinked from ~/dotfiles/zsh/.zshenv
[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"

# cmux attaches its computer-use MCP (cmux-cua) to every claude/codex it launches, and the
# computerUse.enabled setting alone doesn't stop that; only this variable does.
export CMUX_COMPUTER_USE_MCP_DISABLED=1
