#!/usr/bin/env bash
# Integration tests for taar. Runs against the real Beads engine in an isolated HOME, using a
# local bare git repo in place of GitHub. Nothing outside a temp directory is touched.
#
#   tests/run.sh
set -u

ROOT=$(cd "$(dirname "$0")/.." && pwd)
T=$(cd "$(mktemp -d)" && pwd -P)   # canonical (macOS temp dirs sit behind the /var -> /private/var symlink)
trap 'rm -rf "$T"' EXIT

export HOME="$T/home"
export XDG_CONFIG_HOME="$HOME/.config"
export GIT_CONFIG_GLOBAL="$T/gitconfig"
export GIT_CONFIG_NOSYSTEM=1
export BD_NON_INTERACTIVE=1
unset TODO_DIR TAAR_WORKSPACE
mkdir -p "$HOME/.local/bin" "$HOME/.claude"
git config --global user.name "Taar Test"
git config --global user.email "test@example.com"
git config --global init.defaultBranch main

# Install the command the way install.sh does.
ln -s "$ROOT/bin/taar" "$HOME/.local/bin/taar"
export PATH="$HOME/.local/bin:$PATH"

pass=0; fail=0
ok()   { pass=$((pass + 1)); printf '  ok    %s\n' "$1"; }
bad()  { fail=$((fail + 1)); printf '  FAIL  %s\n' "$1"; [ -n "${2:-}" ] && printf '%s\n' "$2" | sed 's/^/        /'; }
# check "description" command...            -> command must succeed
check() { local d="$1"; shift; local out; if out=$("$@" 2>&1); then ok "$d"; else bad "$d" "$out"; fi; }
# check_fails "description" command...      -> command must fail
check_fails() { local d="$1"; shift; local out; if out=$("$@" 2>&1); then bad "$d" "$out"; else ok "$d"; fi; }
# has "description" "pattern" command...    -> output must match pattern
has() { local d="$1" p="$2"; shift 2; local out; out=$("$@" 2>&1); if printf '%s' "$out" | grep -qE -- "$p"; then ok "$d"; else bad "$d" "$out"; fi; }
# lacks "description" "pattern" command...  -> output must not match pattern
lacks() { local d="$1" p="$2"; shift 2; local out; out=$("$@" 2>&1); if printf '%s' "$out" | grep -qE -- "$p"; then bad "$d" "$out"; else ok "$d"; fi; }
in_dir() { local d="$1"; shift; (cd "$d" && "$@"); }
# no_hang cmd...: run with a 15s limit; exit 142 means it hung.
no_hang() { perl -e 'alarm 15; exec @ARGV' "$@"; }
id_of() { in_dir "$1" taar list --all --closed --json 2>/dev/null | python3 -I -c 'import json,sys; t=sys.argv[1]; print([i["id"] for i in json.load(sys.stdin) if i["title"]==t][0])' "$2"; }

echo "taar tests (Beads $(bd version | awk '{print $3}'))"

echo "-- basics without a workspace"
check  "bash syntax" bash -n "$ROOT/bin/taar"
has    "help works" "taar workspace create" taar help
has    "version shows taar and beads" "taar .*" taar version
check_fails "list without workspace fails" taar list
has    "list without workspace explains next step" "workspace create" taar list
has    "prime works without workspace" "No taar workspace" taar prime

echo "-- workspace create (local bare remote as GitHub)"
git init -q --bare "$T/remote.git"
check  "create workspace" taar workspace create -y --name team --dir "$T/ws" --prefix tst --url "$T/remote.git" --no-agents
check  "workspace has Beads database" test -d "$T/ws/.beads"
check  "workspace has registry" test -f "$T/ws/projects.tsv"
check  "workspace has agent docs" grep -q "taar prime" "$T/ws/CLAUDE.md"
has    "config points at workspace" "workspace=$T/ws" cat "$XDG_CONFIG_HOME/taar/config"
has    "todo database pushed to remote" "refs/dolt/data" git -C "$T/remote.git" for-each-ref
has    "workspace show" "Remote: +$T/remote.git" taar workspace
has    "workspace show counts projects once" "^Projects: +0$" sh -c "taar workspace | grep Projects"
has    "workspace README has join URL" "taar workspace join $T/remote.git" cat "$T/ws/README.md"
check  "second workspace with default prefix" taar workspace create -y --name solo --dir "$T/solo" --no-github --no-agents
check  "create todo in second workspace" taar create "Prefix check" -q
has    "default ID prefix is taar" "taar-[a-z0-9]+ .*Prefix check" taar list
check  "switch back to main workspace" taar workspace use "$T/ws"
check_fails "create refuses non-empty dir" taar workspace create -y --name team --dir "$T/ws" --no-github --no-agents
mkdir -p "$T/rel"
check  "create with a relative --dir" in_dir "$T/rel" taar workspace create -y --name=relative --dir=relws --no-github --no-agents
has    "relative --dir stored as an absolute path" "workspace=$T/rel/relws$" cat "$XDG_CONFIG_HOME/taar/config"
check  "relative workspace has its files in the right place" test -f "$T/rel/relws/projects.tsv"
check  "new workspaces merge projects.tsv by union" grep -q "projects.tsv merge=union" "$T/rel/relws/.gitattributes"
git init -q --bare "$T/rel/late.git" && git -C "$T/rel/relws" remote add origin "$T/rel/late.git"
mkdir -p "$T/rel/lp" && git -C "$T/rel/lp" init -q && git -C "$T/rel/lp" remote add origin https://github.com/acme/lp.git
has    "share works when the workspace branch has no upstream yet" "pushed project link" in_dir "$T/rel/lp" taar init -y --name lp --agent-files none --share
has    "link really reached the remote" "link project lp" git -C "$T/rel/late.git" log --oneline
check  "back to main workspace" taar workspace use "$T/ws"
for flag in "workspace create --dir" "workspace create --name" "workspace join x --dir" "init --name" "init -y -d"; do
  # shellcheck disable=SC2086  # split the flag list on purpose
  has "missing value for '$flag' fails fast" "needs a value" no_hang taar $flag
done
check_fails "create with unreachable remote fails" taar workspace create -y --name broken --dir "$T/broken" --url "$T/missing.git" --no-agents
check_fails "failed create leaves no folder behind" test -e "$T/broken"
has    "failed create keeps previous workspace active" "workspace=$T/ws$" cat "$XDG_CONFIG_HOME/taar/config"

echo "-- projects"
mkdir -p "$T/proj" && git -C "$T/proj" init -q && git -C "$T/proj" remote add origin git@github.com:Acme/Demo-App.git
printf '# Demo\n\nKeep me.\n\n\n\nAnd me.\n\n<!-- BEGIN BEADS INTEGRATION v:1 -->\nuse bd\n<!-- END BEADS INTEGRATION -->\n' > "$T/proj/CLAUDE.md"
mkdir -p "$T/proj/.claude" && printf '{"hooks":{"SessionStart":[{"hooks":[{"command":"bd prime --hook-json","type":"command"}]}]}}\n' > "$T/proj/.claude/settings.json"
check  "init links project" in_dir "$T/proj" taar init -y --name demo -d "Demo app" --agent-files CLAUDE.md
has    "registry has normalised repo key" "^github.com/acme/demo-app	demo	Demo app$" cat "$T/ws/projects.tsv"
has    "project link pushed" "link project demo" git -C "$T/remote.git" log --oneline
check  "project CLAUDE.md has todo block" grep -q "BEGIN TAAR INTEGRATION" "$T/proj/CLAUDE.md"
check  "project CLAUDE.md keeps own content" grep -q "Keep me." "$T/proj/CLAUDE.md"
has    "project CLAUDE.md keeps its blank lines" "Keep me\.,,,,And me\.," sh -c "tr '\\n' ',' < '$T/proj/CLAUDE.md'"
lacks  "Beads block removed" "BEGIN BEADS" cat "$T/proj/CLAUDE.md"
has    "old prime hook switched" "taar prime --hook-json" cat "$T/proj/.claude/settings.json"
check  "re-init is idempotent" in_dir "$T/proj" taar init -y --no-share
has    "only one todo block after re-init" "^1$" grep -c "BEGIN TAAR INTEGRATION" "$T/proj/CLAUDE.md"
has    "projects lists current project" "^\* demo" in_dir "$T/proj" taar projects
mkdir -p "$T/port" && git -C "$T/port" init -q && git -C "$T/port" remote add origin ssh://git@github.com:22/acme/Port.git
check  "init with an ssh remote that has a port" in_dir "$T/port" taar init -y --name port --agent-files none --no-share -d "$(printf 'esc\033[31m bell\001 cr\r end')"
has    "port is not part of the repo key" "^github.com/acme/port	port	" cat "$T/ws/projects.tsv"
mkdir -p "$T/nouser" && git -C "$T/nouser" init -q && git -C "$T/nouser" remote add origin github.com:Acme/NoUser.git
check  "init with an scp-style remote without a user" in_dir "$T/nouser" taar init -y --name nouser --agent-files none --no-share
has    "scp-style remote without a user normalised" "^github.com/acme/nouser	nouser	" cat "$T/ws/projects.tsv"
check  "prime JSON valid with control characters in a description" sh -c "cd '$T/port' && taar prime --hook-json | python3 -I -c 'import json,sys; json.load(sys.stdin)'"
mkdir -p "$T/plain"
check_fails "init outside git fails" in_dir "$T/plain" taar init -y
check_fails "init in workspace itself fails" in_dir "$T/ws" taar init -y

echo "-- scoping and priorities"
check  "create in project with priority name" in_dir "$T/proj" taar create "Demo task" -p high -d "in project" -q
check  "create outside project with --priority" in_dir "$T/plain" taar create "Other task" --priority low -d "no project" -q
has    "priority name stored as P1" "P1 Demo task" in_dir "$T/proj" taar list
lacks  "project list hides other projects" "Other task" in_dir "$T/proj" taar list
has    "project list --all shows everything" "Other task" in_dir "$T/proj" taar list --all
has    "outside a project shows everything" "Demo task" in_dir "$T/plain" taar list
has    "list -p high filters" "Demo task" in_dir "$T/plain" taar list -p high
lacks  "list -p high excludes low" "Other task" in_dir "$T/plain" taar list -p high
DEMO_ID=$(id_of "$T/proj" "Demo task")
check  "close a todo" in_dir "$T/proj" taar close "$DEMO_ID" --reason "done"
lacks  "closed todo hidden by default" "Demo task" in_dir "$T/proj" taar list
has    "--closed includes closed todos" "Demo task" in_dir "$T/proj" taar list --closed
has    "search includes closed todos" "Demo task" in_dir "$T/proj" taar search Demo
check  "search --closed works" in_dir "$T/proj" taar search Demo --closed
check  "count --closed works" in_dir "$T/proj" taar count --closed
has    "ready --closed explains" "only shows open work" in_dir "$T/proj" taar ready --closed
check  "rename the project" in_dir "$T/proj" taar init -y --name demo-renamed --no-share
has    "renamed project still shows its todos" "Document|Demo" sh -c "cd '$T/proj' && taar list --closed"
has    "todos carry the new project label" "project:demo-renamed" sh -c "cd '$T/proj' && taar search Demo"
lacks  "old label gone" "project:demo[^-]" sh -c "cd '$T/proj' && taar search Demo"
check  "rename back" in_dir "$T/proj" taar init -y --name demo --no-share
lacks  "piped output hides Beads setup tips" "bd setup" sh -c "cd '$T/proj' && taar ready | cat"
check  "todo mentioning bd setup" in_dir "$T/proj" taar create "Document bd setup claude for new hires" -q
has    "piped output keeps todo titles that mention bd setup" "Document bd setup claude" sh -c "cd '$T/proj' && taar list | cat"
has    "JSON output keeps every title" "Document bd setup claude" sh -c "cd '$T/proj' && taar list --json"
check  "legacy TODO_DIR in the environment is ignored" env TODO_DIR="$T/not-a-workspace" taar list
has    "bad TAAR_WORKSPACE is named in the error" "TAAR_WORKSPACE=" env TAAR_WORKSPACE="$T/plain" taar list

echo "-- taar speaks taar (no bd in Beads output)"
BDWORD='(^|[^A-Za-z0-9_./-])bd([^A-Za-z0-9_./-]|$)'
has    "stats hint names taar" "use 'taar list'" taar stats
lacks  "stats has no bd" "$BDWORD" taar stats
has    "stats in a project notes it covers every project" "cover every project" in_dir "$T/proj" taar stats
has    "unknown command error names taar" 'unknown command "nosuch" for "taar"' taar nosuch
check_fails "unknown command still fails" taar nosuch
has    "command help shows taar usage" "taar list \\[flags\\]" taar list --help
lacks  "command help has no bd" "$BDWORD" taar list --help
lacks  "help <command> has no bd" "$BDWORD" taar help dep
has    "help for taar's own commands" "taar workspace create" taar init --help
lacks  "report commands have no bd" "$BDWORD" sh -c "taar types; taar statuses; taar config list; taar metrics; taar memories; taar kv"
has    "missing todo hint names taar" "taar history" taar show nosuch-id
check_fails "missing todo still fails" taar show nosuch-id
for blocked in "dolt push" "setup claude" "bootstrap" "hooks install" "sync"; do
  # shellcheck disable=SC2086
  has "'$blocked' is blocked with a taar alternative" "not available in taar" taar $blocked
done
has    "doctor checks the setup" "Beads engine" taar doctor
check  "doctor passes on a healthy workspace" taar doctor
check  "create a todo whose title mentions bd" taar create "Fix bd list output" -q
has    "list shows the title unchanged" "Fix bd list output" taar list --all
has    "list piped shows the title unchanged" "Fix bd list output" sh -c "taar list --all | cat"
BDT=$(taar list --all --json | python3 -I -c 'import json,sys; print([i["id"] for i in json.load(sys.stdin) if i["title"]=="Fix bd list output"][0])')
has    "show keeps the title unchanged" "Fix bd list output" taar show "$BDT"
has    "update echo keeps the title unchanged" "Fix bd list output" taar update "$BDT" -p low
has    "delete preview hint names taar" "run: taar delete" taar delete "$BDT"
check  "delete the bd-title todo" taar delete "$BDT" --force
same_as_beads() {  # taar's output for a data view equals Beads' own (minus Beads' plugin tip)
  local tip="💡 Tip: Install the beads plugin for automatic workflow context, or run 'bd setup claude' for CLI-only mode"
  # shellcheck disable=SC2068
  diff -B <(cd "$T/ws" && bd $@ 2>/dev/null | grep -vxF -- "$tip") <(cd "$T/ws" && taar $@ 2>/dev/null)
}
check  "list output identical to Beads (minus its tip)" same_as_beads list
check  "ready output identical to Beads" same_as_beads ready
check  "search output identical to Beads" same_as_beads search Demo

echo "-- sync: a colleague joins"
mkdir -p "$T/proj2" && git -C "$T/proj2" init -q && git -C "$T/proj2" remote add origin https://github.com/acme/second.git
check  "init without sharing" in_dir "$T/proj2" taar init -y --name second --agent-files none --no-share
lacks  "unshared link not on remote yet" "link project second" git -C "$T/remote.git" log --oneline
check  "push shares unpushed project links" taar push
has    "project link on remote after push" "link project second" git -C "$T/remote.git" log --oneline
check  "push todos" taar push
check  "join workspace" taar workspace join "$T/remote.git" --dir "$T/ws2" -y --no-agents
has    "config now points at joined workspace" "workspace=$T/ws2" cat "$XDG_CONFIG_HOME/taar/config"
has    "joined workspace sees todos" "Other task" in_dir "$T/plain" taar list
has    "joined workspace knows linked projects" "demo" taar projects
check  "colleague creates a todo" in_dir "$T/proj" taar create "From colleague" -p medium -q
check  "colleague pushes" taar push
check  "switch back to first workspace" taar workspace use "$T/ws"
check  "pull colleague's changes" taar pull
has    "first workspace sees colleague's todo" "From colleague" in_dir "$T/proj" taar list
check_fails "use rejects non-workspace" taar workspace use "$T/plain"
check_fails "join rejects non-workspace repo" taar workspace join "$T/proj" --dir "$T/nope" -y --no-agents
check_fails "failed join leaves no clone behind" test -e "$T/nope"
git clone -q "$T/remote.git" "$T/wrong-clone" && git -C "$T/wrong-clone" remote set-url origin https://github.com/someone/else.git
has    "join refuses a clone of a different repo" "clone of https://github.com/someone/else.git" taar workspace join "$T/remote.git" --dir "$T/wrong-clone" -y --no-agents
check  "join reuses a matching existing clone" taar workspace join "$T/remote.git" --dir "$T/ws2" -y --no-agents
# Two people link different projects at the same time: both links must survive, no conflict.
mkdir -p "$T/pa" "$T/pb"
git -C "$T/pa" init -q && git -C "$T/pa" remote add origin https://github.com/acme/pa.git
git -C "$T/pb" init -q && git -C "$T/pb" remote add origin https://github.com/acme/pb.git
check  "colleague links project pa and shares it" in_dir "$T/pa" taar init -y --name pa --agent-files none --share
check  "switch to first workspace (behind)" taar workspace use "$T/ws"
check  "link project pb while behind" in_dir "$T/pb" taar init -y --name pb --agent-files none --share
has    "both concurrent links kept" "pa.*pb|pb.*pa" sh -c "taar projects | tr '\\n' ' '"
lacks  "no conflict markers in projects.tsv" "^(<<<<<<<|=======|>>>>>>>)" cat "$T/ws/projects.tsv"
check  "pull after concurrent links" taar pull
check  "no rebase left in progress" test ! -d "$T/ws/.git/rebase-merge"
# Concurrent edits of the same project merge into two rows: taar must collapse them on sync and
# read the same row everywhere.
printf 'github.com/acme/pa\tpa-stale\tstale row\n' >> "$T/ws/projects.tsv"
printf 'github.com/acme/pa\tpa\tcurrent row\n' >> "$T/ws/projects.tsv"
git -C "$T/ws" commit -qam "simulate a union merge of two edits"
check  "pull tidies duplicate project rows" taar pull
has    "one row per project after tidy" "^1$" grep -c "^github.com/acme/pa	" "$T/ws/projects.tsv"
has    "projects and scoping agree on the row" "Project: pa " sh -c "cd '$T/pa' && taar list 2>&1 >/dev/null"
has    "projects shows the same row" "^\* pa +current row" in_dir "$T/pa" taar projects
check  "back to joined workspace" taar workspace join "$T/remote.git" --dir "$T/ws2" -y --no-agents
check  "back to first workspace" taar workspace use "$T/ws"

echo "-- AI agents"
has    "prime names current project" "Current project: .demo" in_dir "$T/proj" taar prime
check  "prime --hook-json is valid JSON" sh -c "cd '$T/proj' && taar prime --hook-json | python3 -I -c 'import json,sys; json.load(sys.stdin)'"
check  "agents installs global block" taar agents
check  "agents block in ~/.claude/CLAUDE.md" grep -q "BEGIN TAAR GLOBAL" "$HOME/.claude/CLAUDE.md"
check  "agents is idempotent" taar agents
has    "one global block" "^1$" grep -c "BEGIN TAAR GLOBAL" "$HOME/.claude/CLAUDE.md"
check  "agents --remove" taar agents --remove
lacks  "global block removed" "TAAR GLOBAL" cat "$HOME/.claude/CLAUDE.md"
# A dotfiles-managed CLAUDE.md is a symlink: it must stay one, and the rest of it must not change.
mkdir -p "$T/dotfiles" && printf '# Mine\n\nline A\n\n\n\nline B' > "$T/dotfiles/CLAUDE.md"
cp "$T/dotfiles/CLAUDE.md" "$T/dotfiles/original" && printf '\n' >> "$T/dotfiles/original"
rm -f "$HOME/.claude/CLAUDE.md" && ln -s "$T/dotfiles/CLAUDE.md" "$HOME/.claude/CLAUDE.md"
check  "agents on a symlinked file" taar agents
check  "agents update on a symlinked file" taar agents
check  "symlink kept after update" test -L "$HOME/.claude/CLAUDE.md"
has    "block written through the symlink" "^1$" grep -c "BEGIN TAAR GLOBAL" "$T/dotfiles/CLAUDE.md"
check  "agents --remove on a symlinked file" taar agents --remove
check  "symlink kept after remove" test -L "$HOME/.claude/CLAUDE.md"
check  "rest of the file unchanged (blank lines kept)" cmp "$T/dotfiles/CLAUDE.md" "$T/dotfiles/original"
printf '# Mine\n<!-- BEGIN TAAR GLOBAL -->\nold\n## My important rules\nrule 1\n' > "$T/dotfiles/CLAUDE.md"
cp "$T/dotfiles/CLAUDE.md" "$T/dotfiles/broken"
has    "agents refuses a file with a missing end marker" "without a matching" taar agents
check_fails "agents exits non-zero when it refused a file" taar agents
check  "file with a missing end marker left unchanged" cmp "$T/dotfiles/CLAUDE.md" "$T/dotfiles/broken"
printf '# Mine\r\n<!-- BEGIN TAAR GLOBAL -->\r\nold\r\n<!-- END TAAR GLOBAL -->\r\n' > "$T/dotfiles/CLAUDE.md"
check  "agents on a CRLF file" taar agents
has    "CRLF block replaced, not duplicated" "^1$" grep -c "BEGIN TAAR GLOBAL" "$T/dotfiles/CLAUDE.md"
lacks  "CRLF stale block content gone" "^old" cat "$T/dotfiles/CLAUDE.md"
mkdir -p "$T/John Smith/.claude"
check  "agents with spaces in HOME" env HOME="$T/John Smith" taar agents
check  "block written inside the spaced HOME" grep -q "TAAR GLOBAL" "$T/John Smith/.claude/CLAUDE.md"
check_fails "no stray file from word splitting" test -e "$T/John"
check_fails "agents rejects unknown options" taar agents --bogus

echo "-- members (fake GitHub)"
mkdir -p "$T/gh/bin" && export FAKE_GH_DIR="$T/gh"
ln -s "$ROOT/tests/fake-gh" "$T/gh/bin/gh"
printf '[{"login":"owner","role_name":"admin"},{"login":"alice","role_name":"write"},{"login":"orgdev","role_name":"write","via":"org"}]' > "$T/gh/collab.json"
printf '[]' > "$T/gh/inv.json"
git -C "$T/ws" remote set-url origin https://github.com/owner/team.git
gh_path="$T/gh/bin:$PATH"
has    "members lists access" "alice +write" env PATH="$gh_path" taar members
has    "members shows activity by git name" "Taar Test +[0-9]+ todos" env PATH="$gh_path" taar members
has    "invite sends invitation" "Invited bob" env PATH="$gh_path" taar invite bob
has    "invite prints join command" "taar workspace join https://github.com/owner/team" env PATH="$gh_path" taar invite @carol
has    "pending invites listed" "bob +invited 2026-10-12" env PATH="$gh_path" taar members
has    "invite existing member" "alice already has access" env PATH="$gh_path" taar invite alice
check_fails "invite unknown user fails" env PATH="$gh_path" taar invite ghost
has    "remove cancels pending invite" "Cancelled the pending invitation for bob" env PATH="$gh_path" taar remove bob
lacks  "cancelled invite gone" "bob" env PATH="$gh_path" taar members
check  "remove member" env PATH="$gh_path" taar remove alice -y
lacks  "removed member gone" "alice" env PATH="$gh_path" taar members
check_fails "cannot remove owner" env PATH="$gh_path" taar remove owner -y
check_fails "remove non-member fails" env PATH="$gh_path" taar remove dave -y
has    "remove explains organisation access" "through the GitHub organisation" env PATH="$gh_path" taar remove orgdev -y
has    "remove rejects an invalid username" "not a valid GitHub username" env PATH="$gh_path" taar remove 'x" or true or "' -y
has    "invite rejects an invalid username" "not a valid GitHub username" env PATH="$gh_path" taar invite 'bad name'
has    "invite accepts Enterprise Managed User logins" "Invited alice_acme" env PATH="$gh_path" taar invite alice_acme
printf '[{"id":7,"invitee":null,"created_at":"2026-10-12T09:00:00Z"}]' > "$T/gh/inv.json"
has    "members copes with an email invitation" "\\(by email\\)" env PATH="$gh_path" taar members
git -C "$T/ws" remote set-url origin "$T/remote.git"
has    "members needs a GitHub remote" "not on github.com" env PATH="$gh_path" taar members

echo "-- several workspaces"
check  "use a workspace by name" taar workspace use team
has    "workspace list marks the active one" "^\* team " taar workspace list
has    "workspace list shows every workspace" "solo" taar workspace list
git init -q --bare "$T/other.git"
check  "create a second team workspace" taar workspace create -y --name other --dir "$T/other" --url "$T/other.git" --no-agents
mkdir -p "$T/op" && git -C "$T/op" init -q && git -C "$T/op" remote add origin https://github.com/acme/op.git
check  "link a project in the second workspace" in_dir "$T/op" taar init -y --name op --agent-files none --share
check  "create a todo in that project" in_dir "$T/op" taar create "Other team task" -q
check  "switch the active workspace back" taar workspace use team
has    "project picks its own workspace" "Other team task" in_dir "$T/op" taar list
has    "notice names the project's workspace" "Workspace: other \(this project is linked there" in_dir "$T/op" taar list
lacks  "active workspace does not show it" "Other team task" in_dir "$T/plain" taar list
has    "-W by name" "Other team task" in_dir "$T/plain" taar list -W other
has    "--workspace=name" "Other team task" in_dir "$T/plain" taar list --workspace=other
has    "-W by folder" "Other team task" in_dir "$T/plain" taar list -W "$T/other"
has    "-W unknown name explains" "no workspace named 'nosuch'" taar list -W nosuch
check_fails "-W unknown name fails" taar list -W nosuch
has    "-W without a value fails fast" "needs a value" no_hang taar list -W
check  "create with -W from anywhere" in_dir "$T/plain" taar create "Made via flag" -W other -q
has    "todo landed in the named workspace" "Made via flag" taar list -W other
lacks  "and not in the active one" "Made via flag" in_dir "$T/plain" taar list
has    "workspace show with -W explains" "chosen for this command" taar workspace -W other
has    "workspace show in a project explains" "this project is linked in it" in_dir "$T/op" taar workspace
has    "prime mentions other workspaces" "Other workspaces exist" taar prime
check  "rename a workspace" taar workspace rename other team-b
has    "renamed workspace works with -W" "Other team task" taar list -W team-b
check_fails "old name no longer works" taar list -W other
check_fails "rename to a taken name fails" taar workspace rename team-b team
check  "a second folder with the same name" taar workspace create -y --name team-b --dir "$T/x/team-b" --no-github --no-agents
has    "duplicate names get a suffix" "team-b-2" taar workspace list
has    "pull in a Mac-only workspace explains" "on this Mac only" taar pull -W team-b-2
check  "pull in a Mac-only workspace succeeds" taar pull -W team-b-2
check  "forget a workspace" taar workspace forget team-b
lacks  "forgotten workspace not listed" "team-b " taar workspace list
check  "forgotten folder untouched" test -d "$T/other/.beads"
check  "use it again by folder (re-registers)" taar workspace use "$T/other"
has    "re-registered by folder name" "^\* other " taar workspace list
check  "the active one (team-b-2) can be forgotten" taar workspace use team-b-2
check  "forget the active workspace" taar workspace forget team-b-2
has    "no active workspace afterwards" "no active workspace. Choose one" in_dir "$T/plain" taar list
check  "choose an active workspace again" taar workspace use team
git init -q --bare "$T/lonely.git"
check  "Mac-only workspace" taar workspace create -y --name lonely --dir "$T/lonely" --no-github --no-agents
check  "connect it to a remote" taar workspace connect "$T/lonely.git"
has    "connected workspace pushed its todos" "refs/dolt/data" git -C "$T/lonely.git" for-each-ref
check  "pull works after connect" taar pull
check_fails "connect twice fails" taar workspace connect "$T/lonely.git"
check  "back to team" taar workspace use team
has    "pull --all-workspaces visits each" "== team .*|== other " sh -c "taar pull --all-workspaces 2>&1 | tr '\\n' ' '"
check  "pull --all-workspaces succeeds" taar pull --all-workspaces
check  "push --all-workspaces succeeds" taar push --all-workspaces
taar workspace create -y --name gone --dir "$T/gone" --no-github --no-agents >/dev/null 2>&1
mv "$T/gone" "$T/gone-moved"
check  "back to team after creating gone" taar workspace use team
has    "list flags a missing workspace" "missing \(taar workspace forget gone\)" taar workspace list
check_fails "all-workspaces fails if one is missing" taar pull --all-workspaces
has    "doctor notes the missing workspace" "missing workspace folder" taar doctor
check  "forget the missing workspace" taar workspace forget gone
mv "$XDG_CONFIG_HOME/taar/workspaces" "$T/workspaces.saved"
has    "older setups: active workspace registered automatically" "^\* ws " taar workspace list
mv "$T/workspaces.saved" "$XDG_CONFIG_HOME/taar/workspaces"

echo "-- several workspaces: QA regressions"
# 1. TAAR_WORKSPACE: relative paths and names, like -W
mkdir -p "$T/envcheck"
has    "relative TAAR_WORKSPACE syncs, not 'Mac only'" "Push complete" in_dir "$T" env TAAR_WORKSPACE=other taar push
has    "TAAR_WORKSPACE accepts a relative folder" "Other team task" in_dir "$T" env TAAR_WORKSPACE=./other taar list
has    "TAAR_WORKSPACE accepts a name" "Other team task" env TAAR_WORKSPACE=other taar list
# 2. SSH host-alias remotes get a valid sync address
git -C "$T/lonely" remote set-url origin github-acme:org/lonely.git
check_fails "sync remote fixed for an SSH alias (offline is fine)" sh -c "taar push -W lonely 2>&1 | grep -q 'todo sync is not set up'"
has    "SSH alias becomes git+ssh" "git\+ssh://github-acme/org/lonely" sh -c "cd '$T/lonely' && bd dolt remote list"
git -C "$T/lonely" remote set-url origin "$T/lonely.git"
check  "stale sync address is corrected" taar push -W lonely
has    "sync address back to the folder remote" "git\+file://$T/lonely.git" sh -c "cd '$T/lonely' && bd dolt remote list"
# 3. init refuses workspace folders
check_fails "init inside another workspace's folder fails" in_dir "$T/other" taar init -y --agent-files none --no-share
has    "init explains why" "is a taar workspace, not a project" in_dir "$T/other" taar init -y --agent-files none --no-share
lacks  "workspace not added as a project" "github.com/.*/other" cat "$T/ws/projects.tsv"
# 4. one registration per folder, however it is spelled
check  "use by a non-canonical spelling" taar workspace use "$T/x/../other/"
has    "no duplicate registration" "^1$" sh -c "taar workspace list | grep -c ' $T/other$'"
has    "active marker matches" "^\* other " taar workspace list
ln -s "$T/other" "$T/other-link"
check  "use through a symlink" taar workspace use "$T/other-link"
has    "symlink does not duplicate" "^1$" sh -c "taar workspace list | grep -c '^. other '"
mkdir -p "$T/x"
check  "create with a messy --dir" taar workspace create -y --name canon-test --dir "$T/x/../canon-test/" --no-github --no-agents
check  "use it by its clean path" taar workspace use "$T/canon-test"
has    "one registration for both spellings" "^1$" sh -c "taar workspace list | grep -c 'canon-test'"
has    "stored canonically" "^canon-test	$T/canon-test$" cat "$XDG_CONFIG_HOME/taar/workspaces"
check  "forget canon-test" taar workspace forget canon-test
check  "back to team (canonical)" taar workspace use team
# 5. init says which workspace it links in
has    "init names the workspace" "workspace: other" in_dir "$T/op" taar init -y --agent-files none --no-share
has    "init explains the project's own workspace" "already linked there" in_dir "$T/op" taar init -y --agent-files none --no-share
# 6. -W parsing leaves text alone
check  "a description that looks like --workspace is kept" in_dir "$T/plain" taar create "Doc flag" -d "--workspace=other" -q
has    "description stored verbatim" "workspace=other" sh -c "taar show \$(taar list --json | python3 -I -c 'import json,sys; print([i[\"id\"] for i in json.load(sys.stdin) if i[\"title\"]==\"Doc flag\"][0])')"
check  "a title of -W given with --title" in_dir "$T/plain" taar create --title -W -p low -q
has    "title -W stored" " -W$" taar list
has    "-- stops taar's option parsing" "no workspace named" taar list -W nosuch -- -W other
# 7/8. -W where it cannot apply
has    "-W rejected for workspace use" "does not apply" taar workspace use team -W other
has    "-W rejected for workspace create" "does not apply" taar workspace create -y --name z --dir "$T/z" -W other
check_fails "nothing created by the rejected command" test -e "$T/z"
has    "-W and --all-workspaces conflict" "either -W or --all-workspaces" taar pull --all-workspaces -W other
check  "forget leaves one: it becomes active" sh -c "
  export XDG_CONFIG_HOME='$T/solo-cfg'; mkdir -p \"\$XDG_CONFIG_HOME/taar\"
  printf 'a\t$T/ws\nb\t$T/other\n' > \"\$XDG_CONFIG_HOME/taar/workspaces\"
  printf 'workspace=$T/other\n' > \"\$XDG_CONFIG_HOME/taar/config\"
  taar workspace forget b | grep -q \"now 'a'\" && grep -q 'workspace=$T/ws' \"\$XDG_CONFIG_HOME/taar/config\""
# join --name
check  "join with a chosen name" taar workspace join "$T/other.git" --dir "$T/other-joined" --name team-b-mirror -y --no-agents
has    "joined workspace has the chosen name" "^\* team-b-mirror " taar workspace list
check  "back to team after join" taar workspace use team
# connect fills in the README join URL
check  "Mac-only workspace for README check" taar workspace create -y --name readme-ws --dir "$T/readme-ws" --no-github --no-agents
git init -q --bare "$T/readme-ws.git"
check  "connect it" taar workspace connect "$T/readme-ws.git"
has    "README gets the join URL" "taar workspace join $T/readme-ws.git" cat "$T/readme-ws/README.md"
check  "back to team after readme" taar workspace use team

echo "-- installer"
check  "installer syntax" bash -n "$ROOT/install.sh"
# Install from a local clone of the working tree (including uncommitted changes).
git clone -q "$ROOT" "$T/src"
cp -R "$ROOT/bin" "$ROOT/install.sh" "$ROOT/VERSION" "$T/src/"
git -C "$T/src" checkout -q -B taar-test    # CI may be on a detached tag
git -C "$T/src" add -A && git -C "$T/src" commit -qm wip >/dev/null 2>&1
REF=taar-test
install_taar() { env TAAR_REPO="$T/src" TAAR_HOME="$T/install" TAAR_REF="$REF" bash "$ROOT/install.sh"; }
ln -s "$T/old/bin/todo" "$HOME/.local/bin/todo"   # 'todo' link from an earlier version
check  "installer runs" install_taar
has    "taar linked to installed copy" "$T/install/bin/taar" readlink "$HOME/.local/bin/taar"
check_fails "old todo link removed" test -L "$HOME/.local/bin/todo"
has    "installed taar runs" "taar " taar version
check  "installer re-run updates in place" install_taar
check  "upgrade works" taar upgrade
git -C "$T/install" checkout -q --detach v-pin 2>/dev/null || { git -C "$T/src" tag v-pin && git -C "$T/install" fetch -q --tags && git -C "$T/install" checkout -q --detach v-pin; }
has    "upgrade from an install pinned to a tag" "taar " taar upgrade
printf '#!/bin/sh\necho other\n' > "$T/other-todo"; chmod +x "$T/other-todo"; ln -s "$T/other-todo" "$HOME/.local/bin/todo"
check  "installer with a foreign todo" install_taar
has    "foreign todo untouched" "other" "$HOME/.local/bin/todo"
ln -sf "$T/old/bin/taar" "$HOME/.local/bin/todo"
check  "upgrade removes an old todo link" taar upgrade
check_fails "todo link gone after upgrade" test -L "$HOME/.local/bin/todo"

mkdir -p "$T/cbin"
check  "install into a custom bin dir" env TAAR_REPO="$T/src" TAAR_HOME="$T/install" TAAR_REF="$REF" TAAR_BIN="$T/cbin" PATH="$T/cbin:$PATH" bash "$ROOT/install.sh"
rm -f "$HOME/.local/bin/taar"
check  "upgrade through the custom bin dir" env PATH="$T/cbin:$PATH" taar upgrade
check  "upgrade kept the custom bin link" test -L "$T/cbin/taar"
check_fails "upgrade did not add a link elsewhere" test -e "$HOME/.local/bin/taar"

echo
echo "$pass passed, $fail failed"
[ "$fail" = 0 ]
