#!/usr/bin/env bash
# max_out_years.sh — flood 2023–2026 with uniform high daily commits
# so the contribution graph is solid brightest-green (Privacy Screen).
#
# Uses git commit-tree (much faster than git commit --allow-empty).
set -euo pipefail

AUTHOR_NAME="${GIT_AUTHOR_NAME:-SEAN WETHERELL}"
AUTHOR_EMAIL="${GIT_AUTHOR_EMAIL:-seanwwetherell@gmail.com}"
COMMIT_MSG="pattern point"
COMMIT_TIME="12:00:00"
# High uniform count → every active day lands in the top intensity bucket
# when there is little/no lower activity that year.
COUNT_PER_DAY="${COUNT_PER_DAY:-20}"
YEARS=(2023 2024 2025 2026)

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "ERROR: Not inside a Git repository." >&2
  exit 1
fi

export GIT_AUTHOR_NAME="${AUTHOR_NAME}"
export GIT_COMMITTER_NAME="${AUTHOR_NAME}"
export GIT_AUTHOR_EMAIL="${AUTHOR_EMAIL}"
export GIT_COMMITTER_EMAIL="${AUTHOR_EMAIL}"

TREE="$(git write-tree)"
PARENT="$(git rev-parse HEAD)"

echo "=== Max-out contribution flood ==="
echo "Years: ${YEARS[*]}"
echo "Commits/day: ${COUNT_PER_DAY}"
echo "Author: ${AUTHOR_NAME} <${AUTHOR_EMAIL}>"
echo

python3 - "${TREE}" "${PARENT}" "${COMMIT_MSG}" "${COMMIT_TIME}" "${COUNT_PER_DAY}" "${YEARS[@]}" <<'PY'
import os, sys, subprocess
from datetime import date, timedelta

tree, parent, msg, time_s, count_s, *years = sys.argv[1:]
count = int(count_s)
years = [int(y) for y in years]

def is_leap(y: int) -> bool:
    return y % 4 == 0 and (y % 100 != 0 or y % 400 == 0)

def year_days(y: int):
    n = 366 if is_leap(y) else 365
    start = date(y, 1, 1)
    for i in range(n):
        yield start + timedelta(days=i)

env_base = os.environ.copy()
total = 0
days = 0

for y in years:
    for d in year_days(y):
        days += 1
        stamp = f"{d.isoformat()} {time_s}"
        env = env_base.copy()
        env["GIT_AUTHOR_DATE"] = stamp
        env["GIT_COMMITTER_DATE"] = stamp
        for _ in range(count):
            parent = subprocess.check_output(
                ["git", "commit-tree", tree, "-p", parent, "-m", msg],
                env=env,
                text=True,
            ).strip()
            total += 1
        if days % 50 == 0:
            print(f"  … {d.isoformat()} ({total} commits so far)", flush=True)

subprocess.check_call(["git", "update-ref", "HEAD", parent])
print(f"\nDone. {days} day(s), {total} commit(s). HEAD={parent[:12]}")
print("Push with: git push --force-with-lease origin main")
PY
