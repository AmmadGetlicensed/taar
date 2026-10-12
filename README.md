# taar

**Shared todos for your team and your AI agents.** One todo list across all your projects, synced
with colleagues through GitHub, where every todo remembers what it is for and how far it got.
Built on [Beads](https://github.com/gastownhall/beads); you only ever type `taar`.

```bash
taar create "Fix slow login query" -p high -d "Why: login takes 4s. Goal: under 500ms."
taar list            # inside a project: only that project's todos
taar list --all      # every project
```

macOS only for now.

## Contents

- [What taar is](#what-taar-is)
- [The walkthrough](#the-walkthrough)
  1. [Install](#1-install-everyone-once)
  2. [Create your team's workspace](#2-create-your-teams-workspace-one-person-once)
  3. [Invite your team](#3-invite-your-team-owner)
  4. [Join a workspace](#4-join-a-workspace-everyone-else-once)
  5. [Link your projects](#5-link-your-projects-once-per-project)
  6. [Everyday use](#6-everyday-use)
  7. [Working with AI agents](#7-working-with-ai-agents)
  8. [Managing members](#8-managing-members-owner)
  9. [Upgrade and uninstall](#9-upgrade-and-uninstall)
- [Cheat sheet](#cheat-sheet)
- [Command reference](#command-reference)
- [How it works](#how-it-works)
- [Troubleshooting and FAQ](#troubleshooting-and-faq)
- [Development](#development)

## What taar is

Todo lists usually live in one person's head, one project's issue tracker, or one AI chat that
forgets everything next session. taar gives a team **one shared list** that:

- works from **any project folder**, and shows only that project's todos while you are in it;
- gives every todo a **memory**: why it exists, what "done" means, and progress notes that are
  added to, never overwritten;
- is **shared with colleagues** through a private GitHub repo you own;
- is used the same way by **people and AI agents** (Claude Code, Codex).

There are three pieces:

```
┌─────────────────────┐   ┌────────────────────────────────┐   ┌──────────────────────┐
│ taar (the tool)     │   │ Workspace (your team's todos)  │   │ Your projects        │
│ public, this repo   │   │ private GitHub repo you own    │   │ any git repos        │
│                     │   │                                │   │                      │
│ ~/.taar             │──▶│ ~/Development/acme-todos/      │◀──│ backend-api/         │
│ the `taar` command  │   │  ├─ .beads/      the todos     │   │ website/             │
│                     │   │  ├─ projects.tsv linked        │   │ mobile-app/          │
│ installed with      │   │  │               projects      │   │                      │
│ curl | bash         │   │  └─ README, agent instructions │   │ linked with          │
│                     │   │                                │   │ `taar init`          │
└─────────────────────┘   └────────────────────────────────┘   └──────────────────────┘
```

1. **The tool** is just the `taar` command. It holds no data, so anyone can install it.
2. **A workspace** is where a team's todos live: a private GitHub repo created by
   `taar workspace create`. Each team has its own; your todos never touch anyone else's repo.
3. **Your projects** are ordinary code repos. Linking one with `taar init` lets taar recognise
   when you are working in it.

## The walkthrough

This follows two people: **Ammad**, who sets taar up for his team, and **Sara**, who joins later.
Outputs are real, shortened where marked `...`.

### 1. Install (everyone, once)

```bash
curl -fsSL https://raw.githubusercontent.com/AmmadGetlicensed/taar/main/install.sh | bash
```
```
Installing taar...
  Beads engine found: bd version 1.3.1 (Homebrew)
  downloading taar into /Users/sara/.taar
  linked /Users/sara/.local/bin/taar

taar 0.3.0 installed.

Next:
  New team?          taar workspace create
  Joining a team?    taar workspace join <your team's workspace GitHub URL>
  All commands:      taar help
```

This installs the `taar` command into `~/.local/bin` (adding it to your `PATH` if needed) and the
Beads engine with Homebrew if it is missing. Check with `taar version`.

### 2. Create your team's workspace (one person, once)

The first person on the team creates the workspace:

```bash
taar workspace create
```
```
Creating a new taar workspace for your team.

Workspace name (also the GitHub repo name) [team-todos]: acme-todos
Where to keep it on this Mac [/Users/ammad/Development/acme-todos]:
Todo ID prefix (IDs look like <prefix>-a1b) [taar]:
Create private GitHub repo ammad/acme-todos? [Y/n]: y

  created private GitHub repo ammad/acme-todos
  pushed todo database
  workspace ready at /Users/ammad/Development/acme-todos (now active)
Teach your AI agents (Claude Code, Codex) to use taar in every project? [Y/n]: y
  added taar instructions to /Users/ammad/.claude/CLAUDE.md

Done. Try: taar create "My first todo" -p medium
```

- The GitHub repo is created **private, in your account**, using the
  [GitHub CLI](https://cli.github.com) (`gh`). No `gh`? Create an empty repo on GitHub yourself and
  paste its URL when asked; or leave it blank to keep the workspace on this Mac only.
- The **ID prefix** is what todo IDs start with (`taar-4v0`, `acme-4v0`, ...).
- Saying yes to the last question teaches your AI agents to use taar (see
  [step 7](#7-working-with-ai-agents)).

### 3. Invite your team (owner)

Only people you invite can join; your invitation is the approval step.

```bash
taar invite sara-dev
```
```
Invited sara-dev to ammad/acme-todos. Once they accept the GitHub invitation (email or github.com/notifications),
they can join with:

  curl -fsSL https://raw.githubusercontent.com/AmmadGetlicensed/taar/main/install.sh | bash
  taar workspace join https://github.com/ammad/acme-todos
```

Send Sara those two lines. She accepts the invitation from her GitHub email or notifications.

### 4. Join a workspace (everyone else, once)

```bash
taar workspace join https://github.com/ammad/acme-todos
```
```
Where to keep it on this Mac [/Users/sara/Development/acme-todos]:
  cloned https://github.com/ammad/acme-todos
  todo database ready
  workspace ready at /Users/sara/Development/acme-todos (now active)
Teach your AI agents (Claude Code, Codex) to use taar in every project? [Y/n]: y

Done. Try: taar list
```

Sara now sees the same todos as Ammad. `taar workspace` shows which workspace is active:

```
Workspace: /Users/sara/Development/acme-todos
Remote:    https://github.com/ammad/acme-todos.git
Projects:  2
```

### 5. Link your projects (once per project)

Go into any git project (new or existing) and run `taar init`:

```bash
cd ~/Development/backend-api
taar init
```
```
Linking project at /Users/ammad/Development/backend-api
  repo key: github.com/acme/backend-api

Project name (used as label project:<name>) [backend-api]:
One-line description (what is this project?): Licensing REST API
  registered 'backend-api' in the workspace
Add AI agent instructions (use 'taar' for tasks) to this project? [Y/n]: y
Which files (comma-separated) [CLAUDE.md]:
  added taar instructions to /Users/ammad/Development/backend-api/CLAUDE.md
Share this project link with colleagues now (git push the workspace)? [Y/n]: y
  pushed project link to GitHub

Done. In this project: 'taar list' shows only backend-api todos; 'taar create' tags them project:backend-api.
```

- Projects are recognised by their **GitHub address**, so the same project is matched on every
  colleague's Mac, wherever they cloned it, after their next `taar pull`.
- The project's `CLAUDE.md` / `AGENTS.md` gets a short section telling AI agents to use taar. If
  the project had Beads (`bd`) instructions, taar offers to replace them. **Commit those files** in
  the project so colleagues' agents get them too.
- Run `taar init` again any time to change the name or description.

`taar projects` lists linked projects (`*` = the one you are in):

```
* backend-api          Licensing REST API
      github.com/acme/backend-api
  website              Marketing site
      github.com/acme/website
```

### 6. Everyday use

#### Start of the day: get updates

```bash
cd ~/Development/backend-api
taar pull
taar ready
```
```
Project: backend-api  (use --all for every project)
○ taar-4v0 P1 Fix slow login query
○ taar-47t P2 Add rate limiting
...
```

You only see **backend-api** todos because you are in that folder. Outside any linked project,
you see everything.

#### Add a todo, with its memory

```bash
taar create "Fix slow login query" -p high -d "Why: login takes 4s since the users table grew.
Goal: under 500ms.
Constraints: no API changes."
```
```
✓ Created issue: taar-4v0 — Fix slow login query
  Priority: P1
  Status: open
```

- It is tagged with the current project automatically.
- `-p` / `--priority` takes a name:

  | Name | Shown as | Meaning |
  |---|---|---|
  | `critical` | P0 | drop everything |
  | `high` | P1 | do it soon |
  | `medium` | P2 | normal work (default) |
  | `low` | P3 | when there is time |
  | `backlog` | P4 | someday |

- `-d` / `--description` is the todo's memory. A good pattern is **Why / Goal / Constraints**, so
  anyone (or any AI agent) can pick it up later.

#### Work on it

```bash
taar show taar-4v0                     # read purpose, constraints and progress
taar update taar-4v0 --claim           # it's mine, in progress
taar update taar-4v0 --append-notes "Missing index on users.email. Next: add migration."
```
```
◐ taar-4v0 · Fix slow login query   [P1 · IN_PROGRESS]
Created by: Ammad Khan · Assignee: Ammad Khan · Type: task
...
DESCRIPTION
  Why: login takes 4s since the users table grew. ...

NOTES
  Missing index on users.email. Next: add migration.

LABELS: project:backend-api
```

Notes are **appended**, never overwritten. Tomorrow you, Sara, or an AI agent can run
`taar show taar-4v0` and continue where you stopped.

#### Finish it and share

```bash
taar close taar-4v0 --reason "Index added, login now 180ms"
taar push
```
```
✓ Closed taar-4v0 — Fix slow login query: Index added, login now 180ms
Pushing to Dolt remote...
Push complete.
```

`taar push` sends your changes to GitHub; colleagues see them after their next `taar pull`.
**Nothing syncs on its own:** `taar pull` when you start, `taar push` when you finish.

#### Finding things

```bash
taar list                  # this project's open todos
taar list --all            # every project
taar list --closed         # include finished todos
taar list -p high          # only high priority
taar search login          # by keyword
taar update taar-47t -p critical --title "Add rate limiting (urgent)"   # change a todo
```

Anything taar doesn't handle itself goes straight to Beads, so `taar stats`, `taar dep add`,
`taar blocked`, `taar label add` and the rest work too (`taar <command> --help`).

### 7. Working with AI agents

If you said yes to *"Teach your AI agents"* (or ran `taar agents`), Claude Code and Codex know
about taar in every project. Just talk to them:

> "Add a todo to add rate limiting to the login endpoint, medium priority."
> "What's left on this project?"
> "Pick up taar-47t and continue from the notes."

The agent runs `taar ready`, `taar show`, `taar create`, records progress with
`--append-notes`, and runs `taar push` at the end of the session. Agents are told never to call
`bd` directly and never to keep their own todo lists.

Where the instructions live:

| Where | Added by | Purpose |
|---|---|---|
| `~/.claude/CLAUDE.md`, `~/.codex/AGENTS.md` | `taar agents` (or yes during create/join) | every project on this Mac |
| a project's `CLAUDE.md` / `AGENTS.md` | `taar init` | that project, for everyone who clones it |
| `taar prime` | run by agents or a session hook | live briefing: current project, commands, rules |

`taar agents --remove` takes the global instructions out again. To load the briefing
automatically at the start of every Claude Code session, add `taar prime --hook-json` as a
`SessionStart` hook. Workspace repos come with this hook, and `taar init` switches a project's
existing Beads (`bd prime`) hook to it.

### 8. Managing members (owner)

```bash
taar members
```
```
Members of ammad/acme-todos (people who can join and sync):
  ammad                    admin
  sara-dev                 write

Invited, not accepted yet:
  ali-k                    invited 2026-10-12

Activity in todos (by git name; created or claimed):
  Sara Ahmed                 8 todos   last active 2026-10-14
  Ammad Khan                12 todos   last active 2026-10-13
```

```bash
taar remove ali-k          # cancels the pending invitation
taar remove sara-dev       # removes access (asks to confirm)
```

- Who can join is exactly who has access to the workspace's GitHub repo. These commands use the
  GitHub CLI and work for the owner or an admin.
- Removing someone stops them syncing; the copy already on their Mac stays there.
- On a personal GitHub account every member can edit todos. Read-only members need a GitHub
  organisation.
- Activity uses each person's **git name** (from who created or claimed todos) and needs `jq`,
  which is built into recent macOS.

### 9. Upgrade and uninstall

```bash
taar upgrade               # taar 0.3.0 -> 0.4.0
taar version
```

Uninstall: `rm -rf ~/.taar ~/.local/bin/taar ~/.config/taar`. Your workspace repos are untouched.

## Cheat sheet

| When | Command |
|---|---|
| Once per person | install, then `taar workspace join <url>` |
| Once per team | `taar workspace create` |
| Once per project | `taar init` |
| Start of day | `taar pull`, then `taar ready` |
| New todo | `taar create "Title" -p high -d "Why / Goal / Constraints"` |
| Working | `taar show <id>`, `taar update <id> --claim`, `taar update <id> --append-notes "..."` |
| Done | `taar close <id> --reason "..."` |
| End of day | `taar push` |
| Team | `taar members`, `taar invite <user>`, `taar remove <user>` |

## Command reference

| Command | What it does |
|---|---|
| `taar workspace create` | Create a team workspace (private GitHub repo). Flags: `--name`, `--dir`, `--prefix`, `--owner`, `--url`, `--no-github`, `--agents`/`--no-agents`, `-y` |
| `taar workspace join <url>` | Join an existing workspace. Flags: `--dir`, `--agents`/`--no-agents`, `-y` |
| `taar workspace` | Show the active workspace |
| `taar workspace use <path>` | Switch to another workspace on this Mac |
| `taar init` | Link the current git project. Flags: `--name`, `-d`, `--agent-files CLAUDE.md,AGENTS.md\|none`, `--share`/`--no-share`, `--keep-beads`, `-y` |
| `taar projects` | List linked projects |
| `taar members` | Who has access, pending invitations, activity |
| `taar invite <github-user>` | Invite someone to the workspace |
| `taar remove <github-user>` | Remove access or cancel an invitation (`-y` skips confirmation) |
| `taar pull` / `taar push` | Get / share changes |
| `taar list` / `ready` / `search` / `count` | Scoped to the current project; `--all` for every project, `--closed` to include closed |
| `taar create "Title"` | New todo (auto-tagged with the project); `-p`, `-d` |
| `taar show <id>` | Full details, notes and history |
| `taar update <id>` | `--claim`, `--append-notes`, `-p`, `--title`, `--add-label`, ... |
| `taar close <id>` | Finish a todo; `--reason` |
| `taar agents [--remove]` | Add / remove global AI agent instructions |
| `taar prime [--hook-json]` | Workflow briefing for AI agents |
| `taar upgrade` / `taar version` / `taar help` | Maintenance |
| anything else | Passed to Beads, e.g. `taar stats`, `taar dep add`, `taar blocked` |

## How it works

**Every command runs against your workspace, from wherever you are.** When you type
`taar create "Fix login" -p high` inside `~/Development/backend-api`:

1. taar reads the folder's git remote (`github.com/acme/backend-api`) and looks it up in the
   workspace's `projects.tsv`, which says this is project `backend-api`.
2. It translates `-p high` to Beads' priority `1` and adds the label `project:backend-api`.
3. It runs `bd create "Fix login" -p 1 --labels project:backend-api` inside the workspace folder.

`taar list` does the same, filtering by that label; `--all` drops the filter.

```
  You / colleagues / AI agents
          │  taar ...
          ▼
  taar (~/.taar)          project tags, priority names, workspaces, members, agent setup
          │  bd ...
          ▼
  Beads database          inside your workspace folder (.beads/)
          │  taar push / taar pull
          ▼
  Private GitHub repo     shared by everyone you invite
```

**Two things sync, in two ways:**

| What | How | When |
|---|---|---|
| The todos (Beads database) | `taar push` / `taar pull`, stored in a hidden part of the GitHub repo (`refs/dolt/data`) | when you run them |
| The project list (`projects.tsv`) | normal git commits | pushed by `taar init`, fetched by `taar pull` |

Beads keeps full history, so when two people change todos at the same time, both sets of changes
are merged rather than lost.

**Files on your Mac:**

| Path | What |
|---|---|
| `~/.taar/` | the taar tool (a git clone; `taar upgrade` updates it) |
| `~/.local/bin/taar` | the command (a link into `~/.taar`) |
| `~/.config/taar/config` | which workspace is active |
| your workspace folder | `.beads/` (todos), `projects.tsv`, README, agent instructions |

Requirements: macOS, git, [Homebrew](https://brew.sh) (for Beads ≥ 1.2.2). Optional: `gh` (create
workspaces and manage members), `jq` (member activity).

## Troubleshooting and FAQ

**`taar: command not found`**: open a new terminal (the installer added `~/.local/bin` to your
`PATH` in `~/.zshrc`), or run `source ~/.zshrc`.

**`taar: no workspace yet`**: run `taar workspace create` (new team) or
`taar workspace join <url>` (existing team).

**`could not clone ... (do you have access?)` when joining**: accept the GitHub invitation first,
and make sure git can reach GitHub (`gh auth login` sets this up).

**I made a todo before linking the project and it doesn't show up in the project.** Only todos
created inside a linked project are tagged. Tag it yourself:
`taar update <id> --add-label project:<name>`.

**A colleague's changes aren't showing.** They need to `taar push`, then you `taar pull`.

**`taar push` failed.** Usually someone pushed first: run `taar pull`, then `taar push` again.

**Can I have several workspaces?** Yes, for example one per team. Join or create each one, then
switch with `taar workspace use <path>`.

**Can members be read-only?** Not on a personal GitHub account: everyone you invite can edit. Use a
GitHub organisation for read-only access.

**Are my todos private?** Yes. They live in your private workspace repo; only people with access
to it can see them. The taar tool repo contains no todos. Note that Beads itself sends anonymous
usage metrics (which commands run, never your content); turn that off with `bd metrics off`.

**Can I still use `bd` directly?** You can, inside the workspace folder, but there should be no
need: everything goes through `taar`, and anything taar doesn't handle is passed to Beads.

**Linux or Windows?** macOS only for now.

## Development

The whole tool is `bin/taar` (bash, compatible with macOS bash 3.2) plus `install.sh`.

```bash
tests/run.sh                                                       # integration tests
shellcheck -S warning bin/taar install.sh tests/run.sh tests/fake-gh
```

The tests run the real Beads engine in an isolated `HOME`, with a local git repo standing in for
GitHub and a fake `gh` for member commands; they never touch real workspaces or GitHub. CI runs them
on macOS for every push. To release: bump `VERSION`, tag `vX.Y.Z`, push; users get it with
`taar upgrade`.

## License

MIT
