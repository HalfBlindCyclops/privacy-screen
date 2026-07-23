# Privacy Screen

Contribution-graph artwork for the GitHub repository **Privacy Screen** (`privacy-screen`).

## Usage

1. Initialize an empty git repo dedicated to this artwork (do not run in a real project).
2. Edit `pattern.json` — an array of `{ "date": "YYYY-MM-DD", "count": N }` entries.
3. Run:

```bash
./generate_pattern.sh
# or: ./generate_pattern.sh path/to/pattern.json
```

4. Push to the `privacy-screen` remote:

```bash
# first time (creates GitHub repo + remote named origin):
gh repo create privacy-screen --public --source=. --remote=origin --push

# later:
git push -u origin main
```

The script refuses to run if it detects real project source files or non-pattern commit history.
