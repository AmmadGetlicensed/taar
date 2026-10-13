#!/usr/bin/env bash
# taar installer:
#   curl -fsSL https://raw.githubusercontent.com/AmmadGetlicensed/taar/main/install.sh | bash
#
# Installs taar into ~/.taar (a git clone, so `taar upgrade` can update it), links the `taar`
# command into ~/.local/bin, and installs the Beads engine with Homebrew if it is missing.
#
# Environment overrides: TAAR_REPO, TAAR_REF (branch or tag), TAAR_HOME, TAAR_BIN.
# Everything runs inside main() so a partially downloaded script does nothing.

main() {
  set -euo pipefail

  local repo="${TAAR_REPO:-https://github.com/AmmadGetlicensed/taar.git}"
  local ref="${TAAR_REF:-main}"
  local home="${TAAR_HOME:-$HOME/.taar}"
  local bin="${TAAR_BIN:-$HOME/.local/bin}"

  say() { printf '%s\n' "$*"; }
  fail() { printf 'taar install: %s\n' "$*" >&2; exit 1; }

  say "Installing taar..."

  [ "$(uname -s)" = Darwin ] || say "  note: taar currently supports macOS only; continuing anyway."
  command -v git >/dev/null || fail "git is required. Run: xcode-select --install"

  # Beads engine.
  if command -v bd >/dev/null; then
    say "  Beads engine found: $(bd version 2>/dev/null | head -1)"
  elif command -v brew >/dev/null; then
    say "  installing the Beads engine (brew install beads)..."
    brew install beads >/dev/null || fail "brew install beads failed"
  else
    fail "the Beads engine is required. Install Homebrew (https://brew.sh), then: brew install beads"
  fi

  # taar itself.
  if [ -d "$home/.git" ]; then
    say "  updating $home"
    git -C "$home" fetch -q --tags origin || fail "could not fetch updates (check your connection)"
    git -C "$home" checkout -q "$ref" || fail "could not check out $ref (were files in $home changed by hand?)"
    if git -C "$home" symbolic-ref -q HEAD >/dev/null; then    # a branch, not a pinned tag
      git -C "$home" merge -q --ff-only "origin/$ref" || fail "could not update $home to origin/$ref"
    fi
  else
    [ -e "$home" ] && fail "$home exists but is not a taar install; move it away and retry"
    say "  downloading taar into $home"
    git clone -q --branch "$ref" "$repo" "$home" || fail "could not clone $repo"
  fi
  chmod +x "$home/bin/taar"

  # Command. Earlier versions installed `todo`; remove that link if it points at taar or
  # its predecessor wrapper, and leave any other `todo` program alone.
  mkdir -p "$bin"
  [ "$(cd "$bin" && pwd -P)" = "$(cd "$home/bin" && pwd -P)" ] && fail "TAAR_BIN must not be taar's own bin directory ($home/bin)"
  ln -sf "$home/bin/taar" "$bin/taar"
  if [ -L "$bin/todo" ]; then
    case "$(readlink "$bin/todo")" in
      */bin/taar|*/bin/todo) rm -f "$bin/todo"; say "  removed the old 'todo' command (now 'taar')" ;;
    esac
  fi
  say "  linked $bin/taar"

  # Bring the AI agents' taar instructions up to date, where they were installed before.
  local refreshed
  refreshed=$("$home/bin/taar" agents --refresh 2>&1) && [ -n "$refreshed" ] && say "$refreshed"

  # PATH.
  case ":$PATH:" in
    *":$bin:"*) ;;
    *)
      local rc="$HOME/.zshrc"
      case "${SHELL:-}" in */bash) rc="$HOME/.bash_profile" ;; esac
      if ! grep -qs '# taar: PATH' "$rc"; then
        printf '\nexport PATH="%s:$PATH"  # taar: PATH\n' "$bin" >> "$rc"
        say "  added $bin to PATH in $rc (open a new terminal, or run: source $rc)"
      fi ;;
  esac

  say ""
  say "taar $(cat "$home/VERSION") installed."
  say ""
  say "Next:"
  say "  New team?          taar workspace create"
  say "  Joining a team?    taar workspace join <your team's workspace GitHub URL>"
  say "  All commands:      taar help"
}

main "$@"
