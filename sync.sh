#!/usr/bin/env bash
#
# Copy the shared release templates into a consuming repository, or check that
# the copies there have not drifted.
#
# Purpose
#   Two of the shared artefacts cannot be referenced remotely the way the
#   next-version action can, because both have to be real files in the
#   consuming repository's working tree:
#
#     cliff.toml            git-cliff reads it from the repository root
#     .githooks/commit-msg  git runs hooks from the checkout
#
#   So they are copied, and the copies are verified. `--check` is the point of
#   the script: a copy nobody compares is a copy that drifts, and the one that
#   drifts is always the one nobody is looking at.
#
# Prerequisites
#   bash 3.2 (what macOS ships), and a checkout of this repository.
#
# Usage
#   ./sync.sh --check   ../tetrak ../scatterskills    # verify; non-zero on drift
#   ./sync.sh           ../tetrak                     # write the templates in
#   ./sync.sh --check                                 # every sibling it can find
#
# Exit codes
#   0  everything matches (--check), or the copy succeeded
#   1  at least one file has drifted, or a target is not a repository

set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
TEMPLATES="$HERE/templates"

# template file -> where it belongs in a consuming repository
TEMPLATE_NAMES="cliff.toml commit-msg"

destination_for() {
  case "$1" in
    cliff.toml) echo "cliff.toml" ;;
    commit-msg) echo ".githooks/commit-msg" ;;
    *) echo "" ;;
  esac
}

check_only=0
targets=""

for arg in "$@"; do
  case "$arg" in
    --check) check_only=1 ;;
    -h|--help) sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*) echo "unknown option: $arg" >&2; exit 1 ;;
    *) targets="$targets $arg" ;;
  esac
done

# No targets named: every sibling directory that is a git repository and
# already carries at least one of the templates. Only ever *checks* those --
# writing into repositories nobody named is not a thing a sync script should
# decide to do.
if [ -z "$targets" ]; then
  for candidate in "$HERE"/../*/; do
    [ -d "$candidate/.git" ] || continue
    [ "$(cd "$candidate" && pwd)" = "$HERE" ] && continue
    if [ -f "$candidate/cliff.toml" ] || [ -f "$candidate/.githooks/commit-msg" ]; then
      targets="$targets $candidate"
    fi
  done
  if [ "$check_only" -eq 0 ]; then
    echo "Refusing to write into repositories that were not named." >&2
    echo "Name them, or pass --check to verify the ones already carrying templates." >&2
    exit 1
  fi
fi

status=0

for target in $targets; do
  if [ ! -d "$target/.git" ]; then
    echo "not a git repository: $target" >&2
    status=1
    continue
  fi
  name="$(basename "$(cd "$target" && pwd)")"

  for template in $TEMPLATE_NAMES; do
    source_file="$TEMPLATES/$template"
    relative="$(destination_for "$template")"
    destination="$target/$relative"

    if [ "$check_only" -eq 1 ]; then
      if [ ! -f "$destination" ]; then
        # Absent is not drift: not every repository uses every template.
        echo "  $name/$relative — absent, skipped"
        continue
      fi
      if cmp -s "$source_file" "$destination"; then
        echo "  $name/$relative — matches"
      else
        echo "::error::$name/$relative has drifted from the shared template"
        diff -u "$source_file" "$destination" || true
        status=1
      fi
    else
      mkdir -p "$(dirname "$destination")"
      cp "$source_file" "$destination"
      [ "$template" = "commit-msg" ] && chmod +x "$destination"
      echo "  $name/$relative — written"
    fi
  done
done

exit $status
