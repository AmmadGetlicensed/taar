#!/usr/bin/env bash
# Integration tests for taar. Runs against the real Beads engine in an isolated HOME, using a
# local bare git repo in place of GitHub. Nothing outside a temp directory is touched.
#
#   tests/run.sh
set -u

ROOT=$(cd "$(dirname "$0")/.." && pwd)
T=$(mktemp -d)
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

# Install the commands the way install.sh does (todo -> bin/taar).
ln -s "$ROOT/bin/taar" "$HOME/.local/bin/todo"
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
id_of() { in_dir "$1" todo list --all --closed --json 2>/dev/null | python3 -I -c 'import json,sys; t=sys.argv[1]; print([i["id"] for i in json.load(sys.stdin) if i["title"]==t][0])' "$2"; }

echo "taar tests (Beads $(bd version | awk '{print $3}'))"

echo "-- basics without a workspace"
check  "bash syntax" bash -n "$ROOT/bin/taar"
has    "help works" "todo workspace create" todo help
has    "version shows taar and beads" "taar .*" todo version
check_fails "list without workspace fails" todo list
has    "list without workspace explains next step" "workspace create" todo list
has    "prime works without workspace" "No todo workspace" todo prime

echo "-- workspace create (local bare remote as GitHub)"
git init -q --bare "$T/remote.git"
check  "create workspace" todo workspace create -y --name team --dir "$T/ws" --prefix tst --url "$T/remote.git" --no-agents
check  "workspace has Beads database" test -d "$T/ws/.beads"
check  "workspace has registry" test -f "$T/ws/projects.tsv"
check  "workspace has agent docs" grep -q "todo prime" "$T/ws/CLAUDE.md"
has    "config points at workspace" "workspace=$T/ws" cat "$XDG_CONFIG_HOME/taar/config"
has    "todo database pushed to remote" "refs/dolt/data" git -C "$T/remote.git" for-each-ref
has    "workspace show" "Remote: +$T/remote.git" todo workspace
has    "workspace show counts projects once" "^Projects: +0$" sh -c "todo workspace | grep Projects"
has    "workspace README has join URL" "todo workspace join $T/remote.git" cat "$T/ws/README.md"
check_fails "create refuses non-empty dir" todo workspace create -y --name team --dir "$T/ws" --no-github --no-agents

echo "-- projects"
mkdir -p "$T/proj" && git -C "$T/proj" init -q && git -C "$T/proj" remote add origin git@github.com:Acme/Demo-App.git
printf '# Demo\n\nKeep me.\n\n<!-- BEGIN BEADS INTEGRATION v:1 -->\nuse bd\n<!-- END BEADS INTEGRATION -->\n' > "$T/proj/CLAUDE.md"
mkdir -p "$T/proj/.claude" && printf '{"hooks":{"SessionStart":[{"hooks":[{"command":"bd prime --hook-json","type":"command"}]}]}}\n' > "$T/proj/.claude/settings.json"
check  "init links project" in_dir "$T/proj" todo init -y --name demo -d "Demo app" --agent-files CLAUDE.md
has    "registry has normalised repo key" "^github.com/acme/demo-app	demo	Demo app$" cat "$T/ws/projects.tsv"
has    "project link pushed" "link project demo" git -C "$T/remote.git" log --oneline
check  "project CLAUDE.md has todo block" grep -q "BEGIN TAAR INTEGRATION" "$T/proj/CLAUDE.md"
check  "project CLAUDE.md keeps own content" grep -q "Keep me." "$T/proj/CLAUDE.md"
lacks  "Beads block removed" "BEGIN BEADS" cat "$T/proj/CLAUDE.md"
has    "bd prime hook switched" "todo prime --hook-json" cat "$T/proj/.claude/settings.json"
check  "re-init is idempotent" in_dir "$T/proj" todo init -y --no-share
has    "only one todo block after re-init" "^1$" grep -c "BEGIN TAAR INTEGRATION" "$T/proj/CLAUDE.md"
has    "projects lists current project" "^\* demo" in_dir "$T/proj" todo projects
mkdir -p "$T/plain"
check_fails "init outside git fails" in_dir "$T/plain" todo init -y
check_fails "init in workspace itself fails" in_dir "$T/ws" todo init -y

echo "-- scoping and priorities"
check  "create in project with priority name" in_dir "$T/proj" todo create "Demo task" -p high -d "in project" -q
check  "create outside project with --priority" in_dir "$T/plain" todo create "Other task" --priority low -d "no project" -q
has    "priority name stored as P1" "P1 Demo task" in_dir "$T/proj" todo list
lacks  "project list hides other projects" "Other task" in_dir "$T/proj" todo list
has    "project list --all shows everything" "Other task" in_dir "$T/proj" todo list --all
has    "outside a project shows everything" "Demo task" in_dir "$T/plain" todo list
has    "list -p high filters" "Demo task" in_dir "$T/plain" todo list -p high
lacks  "list -p high excludes low" "Other task" in_dir "$T/plain" todo list -p high
DEMO_ID=$(id_of "$T/proj" "Demo task")
check  "close a todo" in_dir "$T/proj" todo close "$DEMO_ID" --reason "done"
lacks  "closed todo hidden by default" "Demo task" in_dir "$T/proj" todo list
has    "--closed includes closed todos" "Demo task" in_dir "$T/proj" todo list --closed

echo "-- sync: a colleague joins"
check  "push todos" todo push
check  "join workspace" todo workspace join "$T/remote.git" --dir "$T/ws2" -y --no-agents
has    "config now points at joined workspace" "workspace=$T/ws2" cat "$XDG_CONFIG_HOME/taar/config"
has    "joined workspace sees todos" "Other task" in_dir "$T/plain" todo list
has    "joined workspace knows linked projects" "demo" todo projects
check  "colleague creates a todo" in_dir "$T/proj" todo create "From colleague" -p medium -q
check  "colleague pushes" todo push
check  "switch back to first workspace" todo workspace use "$T/ws"
check  "pull colleague's changes" todo pull
has    "first workspace sees colleague's todo" "From colleague" in_dir "$T/proj" todo list
check_fails "use rejects non-workspace" todo workspace use "$T/plain"
check_fails "join rejects non-workspace repo" todo workspace join "$T/proj" --dir "$T/nope" -y --no-agents

echo "-- AI agents"
has    "prime names current project" "Current project: .demo" in_dir "$T/proj" todo prime
check  "prime --hook-json is valid JSON" sh -c "cd '$T/proj' && todo prime --hook-json | python3 -I -c 'import json,sys; json.load(sys.stdin)'"
check  "agents installs global block" todo agents
check  "agents block in ~/.claude/CLAUDE.md" grep -q "BEGIN TAAR GLOBAL" "$HOME/.claude/CLAUDE.md"
check  "agents is idempotent" todo agents
has    "one global block" "^1$" grep -c "BEGIN TAAR GLOBAL" "$HOME/.claude/CLAUDE.md"
check  "agents --remove" todo agents --remove
lacks  "global block removed" "TAAR GLOBAL" cat "$HOME/.claude/CLAUDE.md"

echo "-- installer"
check  "installer syntax" bash -n "$ROOT/install.sh"
# Install from a local clone of the working tree (including uncommitted changes).
git clone -q "$ROOT" "$T/src"
cp -R "$ROOT/bin" "$ROOT/install.sh" "$ROOT/VERSION" "$T/src/"
git -C "$T/src" checkout -q -B taar-test    # CI may be on a detached tag
git -C "$T/src" add -A && git -C "$T/src" commit -qm wip >/dev/null 2>&1
REF=taar-test
install_taar() { env TAAR_REPO="$T/src" TAAR_HOME="$T/install" TAAR_REF="$REF" bash "$ROOT/install.sh"; }
rm "$HOME/.local/bin/todo"; ln -s "$T/old/bin/todo" "$HOME/.local/bin/todo"   # previous todo wrapper
check  "installer runs" install_taar
has    "todo linked to installed copy" "$T/install/bin/taar" readlink "$HOME/.local/bin/todo"
check  "taar alias linked" test -L "$HOME/.local/bin/taar"
has    "installed todo runs" "taar " todo version
check  "installer re-run updates in place" install_taar
check  "upgrade works" todo upgrade
rm "$HOME/.local/bin/todo"; printf '#!/bin/sh\necho other\n' > "$HOME/.local/bin/todo"; chmod +x "$HOME/.local/bin/todo"
has    "installer leaves a foreign todo alone" "not taar" install_taar
has    "foreign todo untouched" "other" "$HOME/.local/bin/todo"

echo
echo "$pass passed, $fail failed"
[ "$fail" = 0 ]
