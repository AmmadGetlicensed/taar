#!/usr/bin/env bash
# taar installer:
#   curl -fsSL https://raw.githubusercontent.com/AmmadGetlicensed/taar/main/install.sh | bash
#
# Installs taar into ~/.taar (a git clone, so `todo upgrade` can update it), links the `todo` and
# `taar` commands into ~/.local/bin, and installs the Beads engine with Homebrew if it is missing.
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

  say "Installing taar (todo)..."

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
    git -C "$home" fetch -q --tags origin || fail "could not fetch updates"
    git -C "$home" checkout -q "$ref" || fail "could not check out $ref"
    git -C "$home" pull -q --ff-only origin "$ref" 2>/dev/null || true
  else
    [ -e "$home" ] && fail "$home exists but is not a taar install; move it away and retry"
    say "  downloading taar into $home"
    git clone -q --branch "$ref" "$repo" "$home" || fail "could not clone $repo"
  fi
  chmod +x "$home/bin/taar"

  # Commands. Replace an existing `todo` only if it is a symlink to a taar-style wrapper.
  mkdir -p "$bin"
  ln -sf "$home/bin/taar" "$bin/taar"
  if [ -e "$bin/todo" ] || [ -L "$bin/todo" ]; then
    local target; target=$(readlink "$bin/todo" 2>/dev/null || true)
    case "$target" in
      */bin/taar|*/bin/todo) ln -sf "$home/bin/taar" "$bin/todo" ;;
      *) say "  note: $bin/todo already exists and is not taar; use the 'taar' command instead." ;;
    esac
  else
    ln -s "$home/bin/taar" "$bin/todo"
  fi
  say "  linked $bin/todo and $bin/taar"

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
  say "  New team?          todo workspace create"
  say "  Joining a team?    todo workspace join <your team's workspace GitHub URL>"
  say "  All commands:      todo help"
}

main "$@"
