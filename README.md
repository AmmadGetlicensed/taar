# taar

**Shared todos for your team and your AI agents.** One todo list across all your projects,
synced with colleagues through GitHub, with a memory of what every task is for, built on
[Beads](https://github.com/gastownhall/beads).

You type `todo`; taar handles Beads, sync, and project scoping behind the scenes.

```bash
todo create "Renew SSL certificate" -p high -d "Why: cert expires 20 Oct. Goal: renew before expiry."
todo list            # inside a project: only that project's todos
todo list --all      # everything
```

macOS only for now.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/AmmadGetlicensed/taar/main/install.sh | bash
```

This installs taar into `~/.taar`, adds the `todo` command (and a `taar` alias) to `~/.local/bin`,
and installs the Beads engine with Homebrew if needed.

## Set up your team

Your team's todos live in a **workspace**: a private GitHub repo that belongs to you, not to taar.

**First person on the team** creates it:

```bash
todo workspace create
```

It asks for a name, where to keep it, and an ID prefix, then creates a **private GitHub repo** in
your account (using the [GitHub CLI](https://cli.github.com), `gh`). No `gh`? Create an empty repo
on GitHub yourself and paste its URL when asked. It also offers to teach your AI agents to use
`todo` (see below).

**Everyone else** installs taar, gets access to that repo, and joins:

```bash
todo workspace join https://github.com/<owner>/<workspace>
```

`todo workspace` shows the active workspace; `todo workspace use <path>` switches between several.

## Link your projects

Inside any git project (new or existing):

```bash
todo init
```

It asks for a project name and one-line description, offers to add AI-agent instructions to the
project's `CLAUDE.md` / `AGENTS.md` (replacing any Beads instructions), and shares the link with
your team. Projects are recognised by their GitHub repo, so colleagues working in the same repo
are matched automatically.

Inside a linked project:

- `todo list`, `todo ready`, `todo search`, `todo count` show only this project's todos.
- `--all` shows every project; `--closed` includes closed todos.
- `todo create` tags the todo with the project automatically.

Outside a linked project, everything is shown. `todo projects` lists linked projects.

## Daily use

```bash
todo pull                                   # get colleagues' updates
todo ready                                  # what can I work on?
todo create "Title" -p high -d "Why: ... Goal: ... Constraints: ..."
todo show todo-a1b                          # full context, notes, history
todo update todo-a1b --claim                # it's mine, in progress
todo update todo-a1b --append-notes "Found the cause. Next: write the fix."
todo close todo-a1b --reason "Fixed in v2.3"
todo push                                   # share your changes
```

Priorities: `critical`, `high`, `medium`, `low`, `backlog` (shown as P0–P4) with `-p` or `--priority`.
Descriptions: `-d` or `--description`. Nothing syncs automatically: `todo pull` at the start, `todo push`
at the end.

Any other command is passed to Beads, e.g. `todo stats`, `todo dep add`, `todo update <id> --title`.

## AI agents

```bash
todo agents            # add todo instructions to ~/.claude/CLAUDE.md (and ~/.codex/AGENTS.md)
todo agents --remove   # take them out again
```

Agents are told to use `todo` (never `bd` directly), read a todo before working on it, record
progress with `--append-notes`, and push at the end of a session. `todo prime` prints the full
workflow context for the current project; use `todo prime --hook-json` as a Claude Code
`SessionStart` hook.

## Upgrade and uninstall

```bash
todo upgrade
todo version
```

Uninstall: `rm -rf ~/.taar ~/.local/bin/todo ~/.local/bin/taar ~/.config/taar`. Your workspace
repos are untouched.

## How it works

- **taar** (this repo) is just the CLI: a bash script plus installer.
- A **workspace** is a git repo containing the Beads database (`.beads/`, synced through
  `refs/dolt/data` with `todo push` / `todo pull`) and `projects.tsv`, which maps git repos to
  project names. `~/.config/taar/config` remembers the active workspace.
- Projects are Beads labels (`project:<name>`); taar adds them on create and filters by them on list.

Requirements: macOS, git, [Homebrew](https://brew.sh) (for Beads ≥ 1.2.2). `gh` is optional.

## Development

```bash
tests/run.sh                                  # integration tests (isolated HOME, no network)
shellcheck -S warning bin/taar install.sh tests/run.sh
```

## License

MIT
