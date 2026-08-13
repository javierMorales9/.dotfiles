#!/usr/bin/env bash
set -euo pipefail

# wt-article-ref.sh
#
# Flow:
# 1) Pick or create an article folder (fzf)
# 2) Prompt for a reference worktree folder name (default: "ref", prefilled if fzf is available)
#    - If it already exists: show error and re-prompt
# 3) Create a detached worktree at <article>/<ref-name> pointing to HEAD
# 4) Compute FIRST/LAST:
#      FIRST = merge-base(BASE, HEAD)
#      LAST  = HEAD
# 5) Write <article>/commits.md with FIRST/LAST and the log for FIRST..LAST
#
# Usage:
#   wt-article-ref.sh
#   wt-article-ref.sh --article /path/to/article
#   wt-article-ref.sh --articles-root /path/to/articles
#   wt-article-ref.sh --base origin/main

ARTICLES_ROOT_DEFAULT="/home/javi/personal/articles"
BASE_DEFAULT="origin/main"
DEFAULT_REF_NAME="ref"
NEW_PREFIX="__NEW__:"

ARTICLE_PATH=""
ARTICLES_ROOT="$ARTICLES_ROOT_DEFAULT"
BASE="$BASE_DEFAULT"

die() { echo "Error: $*" >&2; exit 1; }
have_cmd() { command -v "$1" >/dev/null 2>&1; }

sanitize_name() {
  # Keep folder names safe: letters, numbers, dot, dash, underscore
  echo "$1" | tr -cd '[:alnum:]._-' 
}

create_article_dir() {
  local root="$1"
  local slug="$2"
  [[ -n "$slug" ]] || die "Empty article name."

  slug="$(echo "$slug" | tr ' ' '-' | tr -cd '[:alnum:]._-' )"
  [[ -n "$slug" ]] || die "Invalid article name after sanitization."

  local path="$root/$slug"
  if [[ -e "$path" ]]; then
    die "Article already exists: $path"
  fi

  mkdir -p "$path"
  echo "$path"
}

pick_or_create_article_with_fzf() {
  local root="$1"
  [[ -d "$root" ]] || die "Articles root does not exist: $root"

  local items selection
  items="$( (echo "${NEW_PREFIX}Create new article..."; find "$root" -mindepth 1 -maxdepth 1 -type d -printf '%p\n' | sort) )"

  selection="$(echo "$items" | fzf --prompt="Select article > " --height=40% --reverse)"
  [[ -n "${selection:-}" ]] || die "No article selected."

  if [[ "$selection" == "${NEW_PREFIX}Create new article..." ]]; then
    local slug
    # Prefill nothing here; user types slug in query
    slug="$(printf "" | fzf --print-query --prompt="New article slug > " --height=10% --reverse | head -n 1)"
    [[ -n "${slug:-}" ]] || die "No slug provided."
    create_article_dir "$root" "$slug"
  else
    echo "$selection"
  fi
}

prompt_ref_name_once() {
  local input=""
  if have_cmd fzf; then
    # Prefill default value in the query so Enter accepts it instantly.
    input="$(printf "" | fzf --print-query --query "$DEFAULT_REF_NAME" --prompt="Ref folder name > " --height=10% --reverse | head -n 1)"
  else
    read -r -p "Ref folder name [$DEFAULT_REF_NAME]: " input
  fi

  input="${input:-$DEFAULT_REF_NAME}"
  input="$(sanitize_name "$input")"
  [[ -n "$input" ]] || die "Invalid ref folder name after sanitization."
  echo "$input"
}

prompt_ref_name_until_free() {
  local article="$1"
  while true; do
    local name
    name="$(prompt_ref_name_once)"

    local wt_dir="$article/$name"
    if [[ -e "$wt_dir" ]]; then
      echo "Error: ref folder already exists: $wt_dir" >&2
      echo "Please choose another name." >&2
      continue
    fi

    echo "$name"
    return 0
  done
}

write_commits_md() {
  local article="$1"
  local base_ref="$2"
  local first_sha="$3"
  local last_sha="$4"

  local out="$article/commits.md"

  {
    echo "# Commit range for this article"
    echo
    echo "- **Base ref**: \`$base_ref\`"
    echo "- **FIRST (merge-base)**: \`$first_sha\`"
    echo "- **LAST (HEAD)**: \`$last_sha\`"
    echo
    echo "## Log (\`$first_sha..$last_sha\`)"
    echo
    echo "\`\`\`"
    # Pretty-ish one-liner log, ordered oldest -> newest for narrative
    git log --reverse --oneline --decorate "$first_sha..$last_sha"
    echo "\`\`\`"
    echo
    echo "## Detailed log"
    echo
    echo "\`\`\`"
    # More detail for writing: hash, author, date, subject
    git log --reverse --date=short --pretty=format:'%h  %ad  %an  %s' "$first_sha..$last_sha"
    echo "\`\`\`"
  } > "$out"

  echo "✅ Wrote $out"
}

# Parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    --article)
      ARTICLE_PATH="${2:-}"; shift 2;;
    --articles-root)
      ARTICLES_ROOT="${2:-}"; shift 2;;
    --base)
      BASE="${2:-}"; shift 2;;
    -h|--help)
      cat <<EOF
Usage:
  wt-article-ref.sh [--article <article-path>] [--articles-root <path>] [--base <base-ref>]

Defaults:
  --articles-root $ARTICLES_ROOT_DEFAULT
  --base          $BASE_DEFAULT

Behavior:
  - Selects (or creates) an article folder via fzf unless --article is provided
  - Prompts for ref folder name (default: "$DEFAULT_REF_NAME", prefilled if fzf exists)
  - If the ref folder exists, shows an error and re-prompts
  - Creates detached worktree at: <article>/<ref-name> (points to HEAD)
  - Computes FIRST/LAST:
      FIRST = merge-base(BASE, HEAD)
      LAST  = HEAD
  - Writes <article>/commits.md containing FIRST/LAST and commit logs for FIRST..LAST
EOF
      exit 0;;
    *)
      die "Unknown argument: $1";;
  esac
done

# Ensure we're in a git repo
git rev-parse --git-dir >/dev/null 2>&1 || die "Current directory is not inside a git repository."

# Fetch if possible (so origin/main is up to date); won't fail if no remotes
git fetch --all --prune >/dev/null 2>&1 || true

# Pick or create article folder
if [[ -z "$ARTICLE_PATH" ]]; then
  have_cmd fzf || die "fzf not found and --article not provided. Install fzf or pass --article /path/to/article"
  ARTICLE_PATH="$(pick_or_create_article_with_fzf "$ARTICLES_ROOT")"
fi

[[ -d "$ARTICLE_PATH" ]] || die "Article path is not a directory: $ARTICLE_PATH"

# Prompt for ref folder name; re-prompt on collisions
REF_NAME="$(prompt_ref_name_until_free "$ARTICLE_PATH")"

# Compute LAST (HEAD)
LAST_SHA="$(git rev-parse --verify "HEAD^{commit}")"

# Compute FIRST = merge-base(BASE, HEAD)
FIRST_SHA="$(git merge-base "$BASE" "$LAST_SHA" 2>/dev/null || true)"
[[ -n "$FIRST_SHA" ]] || die "Could not compute merge-base between '$BASE' and HEAD. Check --base (origin/main vs origin/master)."

# Create <article>/<ref-name> (now guaranteed non-existing)
WT_DIR="$ARTICLE_PATH/$REF_NAME"

# Create detached worktree at HEAD
git worktree add --detach "$WT_DIR" "$LAST_SHA"

echo "✅ Created detached worktree:"
echo "   Article : $ARTICLE_PATH"
echo "   Ref name: $REF_NAME"
echo "   Path    : $WT_DIR"
echo
echo "Range (branch changes):"
echo "   FIRST (merge-base $BASE): $FIRST_SHA"
echo "   LAST  (HEAD)           : $LAST_SHA"
echo

# Write commits.md in the article folder
write_commits_md "$ARTICLE_PATH" "$BASE" "$FIRST_SHA" "$LAST_SHA"
