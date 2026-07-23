#!/usr/bin/env bash
# generate_pattern.sh — create dated empty commits from pattern.json
# for GitHub contribution-graph artwork ("Privacy Screen").
#
# Target GitHub repo: Privacy Screen (slug: privacy-screen)
#
# SAFETY: Refuses to run unless the repo is empty/new and free of real
# project source. See safety_check() below.
set -euo pipefail

PATTERN_FILE="${1:-pattern.json}"
COMMIT_MSG="pattern point"
COMMIT_TIME="12:00:00"
REPO_TITLE="Privacy Screen"
REPO_SLUG="privacy-screen"

# ---------------------------------------------------------------------------
# Safety check
#
# Goal: never accidentally paint a contribution graph on a real project.
#
# We require:
#   1. We are inside a Git repository.
#   2. No common project/source files are tracked (or present untracked
#      in a way that looks like a real codebase) — e.g. *.py, *.js,
#      package.json, src/, etc. Allowed tracked files only:
#      generate_pattern.sh, pattern.json, README.md (pattern tooling).
#   3. Either there are no commits yet, OR every existing commit message
#      is exactly our pattern marker ("pattern point"), OR the repo only
#      contains the pattern tooling files above (dedicated artwork repo
#      with a bootstrap commit). Any other history/source is refused.
# ---------------------------------------------------------------------------
safety_check() {
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "ERROR: Not inside a Git repository." >&2
    echo "       Run 'git init' in an empty directory dedicated to graph artwork first." >&2
    exit 1
  fi

  # Refuse if common source / project markers exist (tracked or untracked).
  local dangerous
  dangerous="$(
    {
      # Tracked files that look like real project source
      git ls-files -z 2>/dev/null | tr '\0' '\n'
      # Also scan the working tree for obvious project roots
      find . -maxdepth 3 \( \
        -name 'package.json' -o -name 'Cargo.toml' -o -name 'go.mod' -o \
        -name 'pyproject.toml' -o -name 'requirements.txt' -o -name 'Gemfile' -o \
        -name 'pom.xml' -o -name 'build.gradle' -o -name 'CMakeLists.txt' -o \
        -name 'Makefile' -o -name '*.py' -o -name '*.js' -o -name '*.ts' -o \
        -name '*.tsx' -o -name '*.jsx' -o -name '*.java' -o -name '*.go' -o \
        -name '*.rs' -o -name '*.c' -o -name '*.cpp' -o -name '*.h' -o \
        -name '*.rb' -o -name '*.php' -o -name '*.swift' -o -name '*.kt' \
      \) -not -path './.git/*' 2>/dev/null
      # Common source directories
      find . -maxdepth 2 -type d \( \
        -name 'src' -o -name 'lib' -o -name 'app' -o -name 'packages' -o \
        -name 'node_modules' -o -name 'vendor' \
      \) -not -path './.git/*' 2>/dev/null
    } | grep -v '^\./generate_pattern\.sh$' | grep -v '^\./pattern\.json$' | grep -v '^\./README\.md$' \
      | grep -v '^generate_pattern\.sh$' | grep -v '^pattern\.json$' | grep -v '^README\.md$' \
      | grep -v '^\.$' | sort -u || true
  )"

  if [[ -n "${dangerous}" ]]; then
    echo "ERROR: Safety check failed — this looks like a real project repository." >&2
    echo "       Found source/project files or directories:" >&2
    echo "${dangerous}" | sed 's/^/         /' >&2
    echo "       This script only runs in an empty repo dedicated to graph artwork." >&2
    exit 1
  fi

  # If there are commits, every one must be a prior pattern commit —
  # unless this is a dedicated artwork repo whose only tracked files are
  # the pattern tooling (bootstrap README + script + pattern.json).
  if git rev-parse --verify HEAD >/dev/null 2>&1; then
    local bad_commits
    bad_commits="$(git log --pretty=%s | grep -v "^${COMMIT_MSG}$" || true)"
    if [[ -n "${bad_commits}" ]]; then
      local tracked
      tracked="$(git ls-files | sort)"
      local allowed=$'README.md\ngenerate_pattern.sh\nmax_out_years.sh\npattern.json'
      # Also accept without max_out_years.sh (older tooling-only layouts).
      local allowed_legacy=$'README.md\ngenerate_pattern.sh\npattern.json'
      if [[ "${tracked}" != "${allowed}" && "${tracked}" != "${allowed_legacy}" ]]; then
        echo "ERROR: Safety check failed — repository already has non-pattern commits." >&2
        echo "       Expected only empty commits with message \"${COMMIT_MSG}\"," >&2
        echo "       or a tooling-only artwork repo (README.md, generate_pattern.sh, pattern.json[, max_out_years.sh])." >&2
        echo "       Offending messages:" >&2
        echo "${bad_commits}" | sort -u | sed 's/^/         /' >&2
        echo "       Use a fresh 'git init' repo with no real project history." >&2
        exit 1
      fi
      echo "Safety check passed: tooling-only artwork repo (non-pattern bootstrap OK); continuing."
    else
      echo "Safety check passed: existing commits are all pattern commits; continuing."
    fi
  else
    echo "Safety check passed: empty repository (no commits yet)."
  fi
}

# ---------------------------------------------------------------------------
# JSON parsing — prefer python3, fall back to jq, else fail clearly.
# Emits lines: DATE<TAB>COUNT
# ---------------------------------------------------------------------------
parse_pattern() {
  local file="$1"
  if [[ ! -f "${file}" ]]; then
    echo "ERROR: Pattern file not found: ${file}" >&2
    exit 1
  fi

  if command -v python3 >/dev/null 2>&1; then
    python3 - "${file}" <<'PY'
import json, sys
path = sys.argv[1]
with open(path, encoding="utf-8") as f:
    data = json.load(f)
if not isinstance(data, list):
    sys.stderr.write("ERROR: pattern.json must be a JSON array of {date, count} objects.\n")
    sys.exit(1)
for i, entry in enumerate(data):
    if not isinstance(entry, dict) or "date" not in entry or "count" not in entry:
        sys.stderr.write(f"ERROR: entry {i} must have 'date' and 'count'.\n")
        sys.exit(1)
    date = entry["date"]
    count = entry["count"]
    if not isinstance(date, str) or len(date) != 10:
        sys.stderr.write(f"ERROR: invalid date at entry {i}: {date!r}\n")
        sys.exit(1)
    if not isinstance(count, int) or isinstance(count, bool) or count < 0:
        sys.stderr.write(f"ERROR: count must be a non-negative integer at entry {i}.\n")
        sys.exit(1)
    print(f"{date}\t{count}")
PY
    return
  fi

  if command -v jq >/dev/null 2>&1; then
    jq -r '
      if type != "array" then
        error("pattern.json must be a JSON array of {date, count} objects.")
      else
        .[] |
        if (.date | type) != "string" or (.count | type) != "number" then
          error("each entry must have string date and numeric count")
        else
          "\(.date)\t\(.count | floor)"
        end
      end
    ' "${file}"
    return
  fi

  echo "ERROR: Need python3 or jq to parse ${file}." >&2
  echo "       Install python3 (recommended) or jq, then re-run." >&2
  exit 1
}

# ---------------------------------------------------------------------------
main() {
  echo "=== Git contribution pattern generator ==="
  echo "Config: ${PATTERN_FILE}"
  echo

  safety_check
  echo

  local total_commits=0
  local days=0

  while IFS=$'\t' read -r date count; do
    days=$((days + 1))
    if [[ "${count}" -eq 0 ]]; then
      echo "Processing ${date}: 0 commits (skipped)"
      continue
    fi

    echo "Processing ${date}: ${count} commits"
    local i
    for ((i = 1; i <= count; i++)); do
      local stamp="${date} ${COMMIT_TIME}"
      GIT_AUTHOR_DATE="${stamp}" \
      GIT_COMMITTER_DATE="${stamp}" \
        git commit --allow-empty -m "${COMMIT_MSG}" >/dev/null
      total_commits=$((total_commits + 1))
    done
  done < <(parse_pattern "${PATTERN_FILE}")

  echo
  echo "Done. Processed ${days} day(s), created ${total_commits} empty commit(s)."
  echo
  echo "Next step — push to GitHub repo \"${REPO_TITLE}\" (slug: ${REPO_SLUG}):"
  echo "  # create once if needed:"
  echo "  #   gh repo create ${REPO_SLUG} --public --source=. --remote=origin --push"
  echo "  # or, if the remote already exists:"
  echo "  git push -u origin main"
}

main "$@"
