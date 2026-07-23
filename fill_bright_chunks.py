#!/usr/bin/env python3
"""
Solid bright-green fill from 2023-01-01 through today, pushed in small
author-date chunks so GitHub's contribution indexer picks up every day
(~100–125 day window per push).
"""
from __future__ import annotations

import os
import subprocess
import time
from datetime import date, timedelta

AUTHOR_NAME = "SEAN WETHERELL"
AUTHOR_EMAIL = "seanwwetherell@gmail.com"
COMMIT_MSG = "pattern point"
COMMIT_TIME = "12:00:00"
COUNT_PER_DAY = 8
CHUNK_DAYS = 100  # stay under GitHub's ~125-day index window per push
START = date(2023, 1, 1)
END = date(2026, 7, 23)  # "now"


def run(cmd, **kwargs):
    return subprocess.check_output(cmd, text=True, **kwargs).strip()


def daterange(a: date, b: date):
    d = a
    while d <= b:
        yield d
        d += timedelta(days=1)


def chunks(start: date, end: date, size: int):
    days = list(daterange(start, end))
    for i in range(0, len(days), size):
        yield days[i : i + size]


def main() -> None:
    env_base = os.environ.copy()
    env_base["GIT_AUTHOR_NAME"] = AUTHOR_NAME
    env_base["GIT_COMMITTER_NAME"] = AUTHOR_NAME
    env_base["GIT_AUTHOR_EMAIL"] = AUTHOR_EMAIL
    env_base["GIT_COMMITTER_EMAIL"] = AUTHOR_EMAIL

    tree = run(["git", "write-tree"])
    all_days = list(daterange(START, END))
    batch_list = list(chunks(START, END, CHUNK_DAYS))
    print(f"Fill {START} → {END}: {len(all_days)} days × {COUNT_PER_DAY} = {len(all_days) * COUNT_PER_DAY} commits")
    print(f"{len(batch_list)} pushes of up to {CHUNK_DAYS} days each\n")

    for idx, batch in enumerate(batch_list, 1):
        parent = run(["git", "rev-parse", "HEAD"])
        total = 0
        print(f"[{idx}/{len(batch_list)}] {batch[0]} → {batch[-1]} ({len(batch)} days)", flush=True)
        for d in batch:
            stamp = f"{d.isoformat()} {COMMIT_TIME}"
            env = env_base.copy()
            env["GIT_AUTHOR_DATE"] = stamp
            env["GIT_COMMITTER_DATE"] = stamp
            for _ in range(COUNT_PER_DAY):
                parent = run(
                    ["git", "commit-tree", tree, "-p", parent, "-m", COMMIT_MSG],
                    env=env,
                )
                total += 1
        subprocess.check_call(["git", "update-ref", "HEAD", parent])
        print(f"  created {total} commits; pushing…", flush=True)
        subprocess.check_call(["git", "push", "origin", "main"])
        print(f"  pushed OK", flush=True)
        time.sleep(1)

    print("\nAll chunks pushed.")


if __name__ == "__main__":
    main()
