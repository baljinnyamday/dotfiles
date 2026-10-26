# Aliases cheatsheet

Reference for everything in `zsh/aliases.zsh`, the command scripts in `bin/`, and the couple of one-offs in `zsh/.zshrc`. Keep this in sync whenever they change — see the note at the bottom.

**Names:** never reuse a command that exists (`cc`, `pr`, `gs` are taken on both OSes, `ip` on Linux); an alias only changes what you type, but it hides the real command from you. `ls` and `python` are the exceptions: same command, better defaults.

**Where a new command goes:** one-line shortcut → alias in `aliases.zsh`. Needs to `cd` or `export` in your current shell → function in `aliases.zsh` (a script runs in its own process and can't). Anything longer → executable script in `bin/`, then `./install.sh` to link it into `~/.local/bin`. Scripts also work from bash, other scripts, tmux/cmux keybindings and agents. Code the `cc*` scripts share (worktree creation, opening a cmux/tmux tab, the agy model lookup, plan naming) lives in `lib/cc.sh`, outside `bin/` so it doesn't land on your PATH.

## Claude Code: quick headless one-offs

- `cla` — alias for `claude` (not `cc`, which is the C compiler)
- `ccmsg` — drafts a commit message from your staged diff (`git diff --staged` piped in)
- `ccf [pytest args]` — runs `uv run pytest` and has Claude fix the failures right in your checkout, then re-run the tests to confirm (does nothing if they already pass). Or pipe in output from anything else: `uv run mypy . |& ccf`, `pnpm build |& ccf` (`|&` also pipes stderr, where most tools print their errors; plain `|` would leave `ccf` with nothing). Headless with `--permission-mode auto`, so you only see Claude's summary at the end; review the changes with `lg`
- `ccstandup [since]` — your commits since `since` (default yesterday; `"last friday"` on a Monday) from the repo you're in, or every repo under `~/coding` and `~/repos` when outside one, plus uncommitted work, turned into a plain-words standup: yesterday / today (guessed from what's uncommitted) / blockers. `ccstandup C` copies it for Slack
- `ccpr` — reviews your branch's diff against `main`, terse bug-focused review
- `ccx <file>` — `claude -p "explain @file concisely"`, quick one-liner explanation
- `ccj "<prompt>"` — runs a prompt, returns just the raw text via `--output-format json | jq -r '.result'`, for piping into scripts
- `ccw` (in `.zshrc`) — runs claude under a separate `~/.ccw` config dir on `claude-fable-5-1`

## Claude Code: big-feature pipeline (plan → review → apply)

- `ccplan "idea" [-o|-s|-h] [-c]` — writes a proposal/design/tasks doc into `openspec/changes/`. No flag = your account's normal default model; `-o`/`-h`/`-s` forces opus/haiku/sonnet; `-c` uses `cursor-agent` (`/opsx-propose`) instead of Claude
- `ccreview` — fzf-pick a proposal, opens its markdown in `bat` to actually read it before trusting it (doesn't call any agent)
- `ccapply <change-name> [-o|-s|-h] [-c]` — implements that change in its own git worktree, opened where you can watch/steer: a new cmux workspace (sidebar tab) inside cmux, so each agent gets its own notifications and session restore; a tmux window inside tmux, and otherwise Claude opens its own tmux session. `-c` runs `cursor-agent` instead (in the current terminal when you're in neither cmux nor tmux)

**Worktrees from `ccapply` / `ccdo`** are Claude Code's own (`claude -w <name>`), not `wt`'s: they live in `.claude/worktrees/<name>/` (gitignored) on a branch `worktree-<name>`, branched from `origin`'s default branch (not your current branch; set `worktree.baseRef: "head"` in Claude settings to change that). When you exit the session, Claude removes a clean worktree and its branch (a named session asks first), and asks keep/remove if there are changes or new commits. Kept ones show up in `wcd` / `wrm` like any other worktree.

## Claude Code: plain-markdown pipeline (ccp → cca → ccr)

The same plan → build → review loop without OpenSpec, for any repo. Plans are plain markdown, and the builder and the reviewer are always separate sessions. Flags on all three: no flag = Claude on your account's default model, `-o`/`-s`/`-h` force opus/sonnet/haiku, `-c` uses `cursor-agent`, `-a` uses `agy` on the newest Gemini Flash.

- `ccp "idea" [-o|-s|-h] [-c|-a]` — plans without editing anything (Claude plan mode, Cursor ask mode, agy plan mode). Prints the plan and saves it to `~/.claude/plans/<slug>.md` (slug = the plan's `# title`), where normal plan mode keeps its plans too
- `cca [plan.md] [-o|-s|-h] [-c|-a]` — builds a plan in a new worktree `.claude/worktrees/<slug>` on branch `worktree-<slug>`, branched from your current HEAD (uncommitted changes stay behind); `plans/<slug>.md` is its only new file. The plan comes from the file argument, from stdin (`ccp "idea" | cca -a`), or with neither from an fzf pick of `~/.claude/plans`, newest first. Opens in a new cmux workspace (a tmux window inside tmux, this terminal otherwise) on auto permissions (table below). The agent is told not to commit
- `ccr [slug] [-o|-s|-h] [-c|-a]` — reviews a `cca` worktree in a fresh headless session, so the builder never grades its own work: Claude's `/code-review`, Cursor's `/review-bugbot` (`-c`), or agy with a review prompt (`-a`). Covers everything since the worktree branched off (commits, uncommitted and untracked files) and checks it against the plan. No slug: the worktree you're in, else an fzf pick. Reviewers are told not to edit, so fixing is up to you or another agent run

Typical run:

```sh
ccp "add rate limiting"          # plan only, saved to ~/.claude/plans/<slug>.md
ccp "add rate limiting" | cca    # plan, then build in a new worktree + cmux tab
cca                              # fzf-pick a saved plan and build it
ccr -c                           # from inside the worktree: fresh Cursor Bugbot review
```

Then commit and `ship` from the worktree, or `wrm -f` to throw it away.

| | Claude (default) | Cursor (`-c`) | agy (`-a`) |
|---|---|---|---|
| `ccp` | plan mode (read-only) | ask mode (read-only) | plan mode + `--dangerously-skip-permissions` |
| `cca` | `--permission-mode auto` | `--force` | `--dangerously-skip-permissions` |
| `ccr` | `--permission-mode auto` | ask mode | `--dangerously-skip-permissions`, told not to edit |

The planners differ because headless Cursor plan mode hangs, and headless agy can't even read files unless every permission is skipped.

## Claude Code: small changes, no ceremony

- `ccdo "task" [-o|-s|-h] [-c|-a]` — same idea as `ccapply` but skips the proposal doc: auto-names a throwaway `quick-<timestamp>` worktree, opens it in its own cmux workspace (a tmux window inside tmux; in neither, Claude opens its own tmux session and cursor-agent/agy run in the current terminal), implements it live. `-a` runs `agy` on the newest Gemini Flash in a worktree the script makes under `.claude/worktrees/`, branched from your HEAD. Outside a git repo there's no worktree: it still opens the new tab, and the agent works right in the current folder
- `ccdoh "task" [-o|-s|-h] [-c|-a]` — headless + backgrounded (`claude --bg`), returns your terminal immediately. Before editing, Claude moves it into its own worktree under `.claude/worktrees/` (branched from `origin`'s default branch, not your current branch), which Claude's periodic sweep removes after `cleanupPeriodDays` if it holds no uncommitted or unpushed work. `-c` (cursor-agent) runs right in your current checkout instead. `-a` (agy on the newest Gemini Flash) also runs in the foreground, but in a new `quick-<timestamp>` worktree branched from your HEAD, since agy skips every permission prompt. Check on it with `claude logs <id>` / `claude attach <id>` / `claude agents`, or just review with `lg` once it's done

## Claude Code: account switching

- `ccas` — fzf-pick which `CLAUDE_CONFIG_DIR` all `cc*` aliases use (`~/.claude` default, `~/.ccw`, or type a new name to create `~/.claude-<name>`). Only affects the current terminal session — a new tab always starts back on default

- `?? <what you want>` — Claude writes one shell command and pushes it onto your prompt line, unrun: enter runs it, Ctrl-C drops it, edit it first if you like. `?? find files over 100MB changed this week`. Question marks and `*` in the question are fine

## Branch / worktree lifecycle

- `cbn <name>` — `git checkout -b <name>`, new branch and switch to it
- `wt <name> [base]` — new worktree + branch in `../<name>`, and cds you into it; branches from `base` (e.g. `dev`, `origin/staging`), defaulting to the current branch
- `wcd` — fzf-pick an existing worktree, cd into it
- `wca <name> [base]` — `wt` for a folder that isn't a repo itself but holds sibling repos (`~/coding/bagsh` with `bagsh.back` + `bagsh.space`). Run from that parent folder: makes one worktree per repo in `../<folder>-wt/<name>/<repo>` (so `~/coding/bagsh-wt/chat/bagsh.back` and `.../bagsh.space`), all on branch `<name>`, and cds you into the feature folder. Open that folder as one workspace/session. `wcd`, `ship`, `wrm` are per-repo, so run them inside each half. Each half needs its own `pnpm install`; `.env` files don't come along, copy or symlink them
- `ship [gh args]` — pushes current branch (`-u`) and opens a PR with `gh pr create --fill`; extra args go to `gh`, e.g. `ship --base dev`
- `wrm [-f]` — fzf-pick a worktree, removes it and deletes its local branch (run this after a PR merges, from outside the worktree: `wcd` to the main checkout first). Refuses if the worktree has uncommitted/untracked files; keeps the branch if its commits aren't merged or pushed anywhere. `-f` removes anyway and force-deletes the branch (what you want after a squash merge); it lists and asks before throwing away uncommitted files, and a deleted branch comes back with `git branch <name> <sha>` using the sha it prints

## fzf pickers, everyday use

- `fcd` — fuzzy-pick any folder below the current one and cd into it
- `y [dir]` — yazi file manager with previews. `q` quits and leaves the shell in the folder you were browsing, `Q` quits without moving. Press `F1` or `~` inside for every key
- `ff` — fuzzy find a file by name, previews it, opens in `cursor` (your Ctrl+P)
- `frg "<text>"` — fuzzy find text inside files (ripgrep), previews the match in `bat`, opens the pick in `cursor`
- `fbr` — fuzzy-switch git branches
- `fkill [-f]` — fuzzy-pick listening port(s)/process(es) (from `lsof`), sends TERM so they shut down cleanly and names any still alive a second later; `-f` sends KILL for the stubborn ones
- `extract <archive>...` — unpacks tar.gz/tgz, tar.bz2, tar.xz, tar, zip, jar, gz, bz2, xz into the current folder, no flags to remember
- `qr [text]` — QR code in the terminal for the text, or the clipboard when there's none; scan it with your phone. `qr "WIFI:T:WPA;S:name;P:pass;;"` joins a wifi
- `notify [msg]` — macOS banner + says it out loud, default "done": `pnpm build; notify`, or `pnpm build && notify built || notify failed`
- `dsh` — fuzzy-pick a running docker container, shells in (`bash` → `sh` → `docker debug` fallback for shell-less images)

## Terminals

- `ts [dir]` — fzf-pick a folder (zoxide history + `~/coding/*`) and jump to it. Inside cmux: switches to the workspace already open in that folder, or creates one. Elsewhere: jumps to its tmux session, creating it if needed (same picker as `prefix f` inside tmux)
- `ghost` — opens a plain Ghostty window in the current folder. cmux is the everyday terminal, Ghostty is the fallback when cmux feels laggy (ssh + tmux)
- `cmux .` — opens the current folder as a new cmux sidebar tab (the `cmux` CLI ships with the app)
- `claude-in <folder> [claude args]` — Claude in a new cmux workspace for that folder (new Ghostty window outside cmux)

## tmux (SSH and the Ghostty fallback only)

Don't run a local tmux inside cmux: cmux sees the whole tmux as one terminal, so per-agent notifications, sidebar status and session restore stop working, and you get two sets of keys. cmux workspaces = tmux sessions, cmux splits = panes (keys in the README). Need a process to survive quitting cmux? `cmux local-tmux start <name>` / `attach <name>`. Remote box? `cmux ssh-tmux <host>`.

- `ta` — attach to the last tmux session, or start one called `main`
- `tl` — list tmux sessions

## Everything else already in `aliases.zsh`

- macOS: `flushdns`, `o` (open .), `ql` (quicklook), `ip`, `pubip`, `cpwd` (copy pwd), `dsclean` (delete .DS_Store), `brewup`
- dev workflow: `killport [-f] <port>` (TERM the listener, `-f` for KILL), `port <port>`, `listening`, `json`/`jsonc` (pbpaste through jq)
- docker/pnpm: `dps`, `dpsa`, `dcu`, `dcd`, `dcl`, `pnr` (pnpm run)
- zsh niceties: global aliases that expand anywhere on the line: `G` (`| grep -i`), `C` (`| pbcopy`, copy the output), `J` (`| jq .`, pretty-print JSON); suffix aliases opening `json/yaml/yml/toml/md/txt` in `bat` and `ts/tsx/js/py/go/rs` in `cursor`

---

**Keeping this file honest:** whenever `zsh/aliases.zsh` or a command script in `bin/` changes, update the matching bullet here in the same commit — don't let this drift into being a stale snapshot of an old design.
