#!/usr/bin/env bash
# Deploy ai-review-caller.yaml to each repo listed in repos.txt
# Opens a PR per repo (idempotent if file already matches).

set -euo pipefail

ORG="${ORG:-Interativa-group}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CALLER_SRC="$ROOT_DIR/workflows/ai-review-caller.yaml"
REPOS_FILE="${REPOS_FILE:-$SCRIPT_DIR/repos.txt}"
WORKFLOW_PATH=".github/workflows/ai-review-caller.yaml"
BRANCH="${BRANCH:-chore/add-ai-code-review}"
WORKDIR="${WORKDIR:-/tmp/ai-code-review-deploy}"
DRY_RUN="${DRY_RUN:-0}"

if [[ ! -f "$CALLER_SRC" ]]; then
  echo "Caller template not found: $CALLER_SRC" >&2
  exit 1
fi

if [[ ! -f "$REPOS_FILE" ]]; then
  echo "repos file not found: $REPOS_FILE" >&2
  exit 1
fi

mkdir -p "$WORKDIR"
mapfile -t REPOS < <(grep -vE '^\s*(#|$)' "$REPOS_FILE" | sed 's/\r$//' | awk '{$1=$1;print}')

if [[ ${#REPOS[@]} -eq 0 ]]; then
  echo "No repos listed in $REPOS_FILE" >&2
  exit 1
fi

echo "Deploying AI review caller to ${#REPOS[@]} repo(s) in $ORG"
echo "Source: $CALLER_SRC"
echo

success=0
skipped=0
failed=0

for repo in "${REPOS[@]}"; do
  full="$ORG/$repo"
  echo "=== $full ==="

  if ! gh repo view "$full" --json name -q .name >/dev/null 2>&1; then
    echo "  SKIP: repo not found or no access"
    ((skipped++)) || true
    continue
  fi

  clone_dir="$WORKDIR/$repo"
  rm -rf "$clone_dir"

  default_branch="$(gh repo view "$full" --json defaultBranchRef -q .defaultBranchRef.name)"
  if [[ -z "$default_branch" ]]; then
    echo "  FAIL: could not resolve default branch"
    ((failed++)) || true
    continue
  fi

  if [[ "$DRY_RUN" == "1" ]]; then
    echo "  DRY_RUN: would add $WORKFLOW_PATH on branch $BRANCH from $default_branch"
    ((success++)) || true
    continue
  fi

  if ! gh repo clone "$full" "$clone_dir" -- --depth 1 -b "$default_branch" >/dev/null 2>&1; then
    echo "  FAIL: clone failed"
    ((failed++)) || true
    continue
  fi

  (
    cd "$clone_dir"
    mkdir -p "$(dirname "$WORKFLOW_PATH")"

    if [[ -f "$WORKFLOW_PATH" ]] && cmp -s "$CALLER_SRC" "$WORKFLOW_PATH"; then
      echo "  SKIP: caller already up to date"
      exit 10
    fi

    # Reset local branch if it already exists from a previous run
    git fetch origin "$default_branch" --depth 1 >/dev/null 2>&1 || true
    git checkout -B "$BRANCH" "origin/$default_branch" >/dev/null 2>&1

    cp "$CALLER_SRC" "$WORKFLOW_PATH"
    git add "$WORKFLOW_PATH"

    if git diff --cached --quiet; then
      echo "  SKIP: nothing to commit"
      exit 10
    fi

    git -c user.email="ai-code-review@interativa.local" \
        -c user.name="Interativa AI Code Review" \
        commit -m "$(cat <<'EOF'
ci: add AI code review workflow on pull requests

Wire the org reusable Gemini review so every PR gets an automated comment.
EOF
)"

    if ! git push -u origin "$BRANCH" --force-with-lease >/dev/null 2>&1; then
      echo "  FAIL: push failed"
      exit 11
    fi

    existing_pr="$(gh pr list --repo "$full" --head "$BRANCH" --state open --json number -q '.[0].number' 2>/dev/null || true)"
    if [[ -n "$existing_pr" ]]; then
      echo "  OK: updated existing PR #$existing_pr"
      exit 0
    fi

    pr_url="$(gh pr create --repo "$full" \
      --base "$default_branch" \
      --head "$BRANCH" \
      --title "ci: add AI code review on pull requests" \
      --body "$(cat <<EOF
## Summary
- Adds \`.github/workflows/ai-review-caller.yaml\` to run the org reusable Gemini review on every PR.
- Uses \`Interativa-group/.github/.github/workflows/ai-review.yaml@main\`.

## Prerequisites
- Org secret \`GEMINI_CODE_REVIEW_API\` must be configured.
- Optional org variable \`GEMINI_MODEL\` (default \`gemini-2.0-flash\`).

## Test plan
- [ ] Merge this PR
- [ ] Open a small test PR and confirm the AI review comment appears
EOF
)")"

    echo "  OK: created $pr_url"
  )
  rc=$?
  if [[ $rc -eq 0 ]]; then
    ((success++)) || true
  elif [[ $rc -eq 10 ]]; then
    ((skipped++)) || true
  else
    ((failed++)) || true
  fi
  echo
done

echo "Done. success=$success skipped=$skipped failed=$failed"
[[ "$failed" -eq 0 ]]
