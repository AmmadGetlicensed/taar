# taar

**Shared todos for your team and your AI agents.** One todo list across all your projects,
synced with colleagues through GitHub, with a memory of what every task is for, built on
[Beads](https://github.com/gastownhall/beads).

You type `taar`; it handles Beads, sync, and project scoping behind the scenes.

```bash
taar create "Renew SSL certificate" -p high -d "Why: cert expires 20 Oct. Goal: renew before expiry."
taar list            # inside a project: only that project's todos
taar list --all      # everything
```

macOS only for now.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/AmmadGetlicensed/taar/main/install.sh | bash
```

This installs taar into `~/.taar`, adds the `taar` command to `~/.local/bin`,
and installs the Beads engine with Homebrew if needed.

## Set up your team

Your team's todos live in a **workspace**: a private GitHub repo that belongs to you, not to taar.

**First person on the team** creates it:

```bash
taar workspace create
```

It asks for a name, where to keep it, and an ID prefix, then creates a **private GitHub repo** in
your account (using the [GitHub CLI](https://cli.github.com), `gh`). No `gh`? Create an empty repo
on GitHub yourself and paste its URL when asked. It also offers to teach your AI agents to use
`taar` (see below).

**Everyone else** installs taar, gets access to that repo, and joins:

```bash
taar workspace join https://github.com/<owner>/<workspace>
```

`taar workspace` shows the active workspace; `taar workspace use <path>` switches between several.

## Members

Who can join is controlled by access to the workspace's GitHub repo. The workspace owner (or an
admin) manages it from the command line, using the GitHub CLI:

```bash
taar members               # who has access, pending invitations, and activity in todos
taar invite alice          # sends a GitHub invitation; prints the join command to send her
taar remove alice          # removes access (or cancels a pending invitation)
```

Joining needs your approval: people can only `taar workspace join` after accepting your invitation.
Removing someone stops them syncing; their existing local copy stays on their machine. On a
personal GitHub account every member can edit todos (read-only members need a GitHub organisation).
Activity is shown by git name, from who created or claimed todos (needs `jq`, built into recent macOS).

## Link your projects

Inside any git project (new or existing):

```bash
taar init
```

It asks for a project name and one-line description, offers to add AI-agent instructions to the
project's `CLAUDE.md` / `AGENTS.md` (replacing any Beads instructions), and shares the link with
your team. Projects are recognised by their GitHub repo, so colleagues working in the same repo
are matched automatically.

Inside a linked project:

- `taar list`, `taar ready`, `taar search`, `taar count` show only this project's todos.
- `--all` shows every project; `--closed` includes closed todos.
- `taar create` tags the todo with the project automatically.

Outside a linked project, everything is shown. `taar projects` lists linked projects.

## Daily use

```bash
taar pull                                   # get colleagues' updates
taar ready                                  # what can I work on?
taar create "Title" -p high -d "Why: ... Goal: ... Constraints: ..."
taar show taar-a1b                          # full context, notes, history
taar update taar-a1b --claim                # it's mine, in progress
taar update taar-a1b --append-notes "Found the cause. Next: write the fix."
taar close taar-a1b --reason "Fixed in v2.3"
taar push                                   # share your changes
```

Priorities: `critical`, `high`, `medium`, `low`, `backlog` (shown as P0–P4) with `-p` or `--priority`.
Descriptions: `-d` or `--description`. Nothing syncs automatically: `taar pull` at the start, `taar push`
at the end.

Any other command is passed to Beads, e.g. `taar stats`, `taar dep add`, `taar update <id> --title`.

## AI agents

```bash
taar agents            # add taar instructions to ~/.claude/CLAUDE.md (and ~/.codex/AGENTS.md)
taar agents --remove   # take them out again
```

Agents are told to use `taar` (never `bd` directly), read a todo before working on it, record
progress with `--append-notes`, and push at the end of a session. `taar prime` prints the full
workflow context for the current project; use `taar prime --hook-json` as a Claude Code
`SessionStart` hook.

## Upgrade and uninstall

```bash
taar upgrade
taar version
```

Uninstall: `rm -rf ~/.taar ~/.local/bin/taar ~/.config/taar`. Your workspace
repos are untouched.

## How it works

- **taar** (this repo) is just the CLI: a bash script plus installer.
- A **workspace** is a git repo containing the Beads database (`.beads/`, synced through
  `refs/dolt/data` with `taar push` / `taar pull`) and `projects.tsv`, which maps git repos to
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
