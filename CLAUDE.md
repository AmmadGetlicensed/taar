# taar: developer notes for AI agents

taar is a CLI for shared team todos built on Beads (`bd`). This repo is the tool only; a
team's todos live in a separate workspace repo created by `taar workspace create`.

- `bin/taar`: the whole CLI (bash). Installed as `taar` via a symlink in `~/.local/bin`.
  Must stay compatible with macOS bash 3.2: no associative arrays, no `${var,,}`, no `mapfile`.
- `install.sh`: the `curl | bash` installer. Keep all logic inside `main()`.
- `tests/run.sh`: integration tests against the real Beads engine in an isolated `HOME`, with a
  local bare git repo standing in for GitHub. Never point tests at real workspaces or GitHub.
- `VERSION`: bump on release, and tag `vX.Y.Z`.

Before finishing a change, run:

```bash
tests/run.sh
shellcheck -S warning bin/taar install.sh tests/run.sh
```

Keep `README.md`, `cmd_help`, and the agent text (`agent_rules`, `project_block`, `global_block`,
`prime_text`) in sync with behavior. Do not commit or push unless the user asks.
