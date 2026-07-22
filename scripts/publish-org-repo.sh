#!/usr/bin/env bash
# Publish local ai-code-review contents to Interativa-group/.github
# Layout: workflows → .github/workflows/ inside the org repo.

set -euo pipefail

ORG="${ORG:-Interativa-group}"
REPO_NAME=".github"
FULL="$ORG/$REPO_NAME"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
WORKDIR="${WORKDIR:-/tmp/interativa-org-github-repo}"
VISIBILITY="${VISIBILITY:-private}"

echo "Publishing $ROOT_DIR → $FULL"

if ! gh repo view "$FULL" --json name -q .name >/dev/null 2>&1; then
  echo "Creating org repository $FULL ($VISIBILITY)..."
  # Repo named .github must live under the org; create via API for reliability.
  gh api -X POST "orgs/$ORG/repos" \
    -f name="$REPO_NAME" \
    -f description="Org reusable workflows and profile (AI Code Review)" \
    -F private="$([[ "$VISIBILITY" == "private" ]] && echo true || echo false)" \
    -F visibility="$VISIBILITY" \
    -F auto_init=true \
    >/dev/null
  # Give GitHub a moment to materialize the repo
  sleep 2
else
  echo "Repository $FULL already exists"
fi

rm -rf "$WORKDIR"
gh repo clone "$FULL" "$WORKDIR" -- --depth 1

cd "$WORKDIR"
default_branch="$(gh repo view "$FULL" --json defaultBranchRef -q .defaultBranchRef.name)"
git fetch origin "$default_branch" --depth 1 >/dev/null 2>&1 || true
git checkout -B "$default_branch" "origin/$default_branch" >/dev/null 2>&1 || git checkout -B "$default_branch"

mkdir -p .github/workflows profile scripts

cp "$ROOT_DIR/workflows/ai-review.yaml" .github/workflows/ai-review.yaml
cp "$ROOT_DIR/workflows/slack.yaml" .github/workflows/slack.yaml
# Keep caller template in repo for reference / deploy source of truth
mkdir -p .github/workflow-templates 2>/dev/null || true
cp "$ROOT_DIR/workflows/ai-review-caller.yaml" scripts/ai-review-caller.yaml
cp "$ROOT_DIR/scripts/deploy-review-workflow.sh" scripts/deploy-review-workflow.sh
cp "$ROOT_DIR/scripts/setup-org-secret.sh" scripts/setup-org-secret.sh
cp "$ROOT_DIR/scripts/publish-org-repo.sh" scripts/publish-org-repo.sh
cp "$ROOT_DIR/scripts/repos.txt" scripts/repos.txt
cp "$ROOT_DIR/README.md" README.md
cp "$ROOT_DIR/profile/README.md" profile/README.md
chmod +x scripts/deploy-review-workflow.sh scripts/setup-org-secret.sh scripts/publish-org-repo.sh

git add -A
if git diff --cached --quiet; then
  echo "Nothing to publish (already up to date)."
  exit 0
fi

git -c user.email="ai-code-review@interativa.local" \
    -c user.name="Interativa AI Code Review" \
    commit -m "$(cat <<'EOF'
feat: add reusable Gemini AI code review workflows

Centralize PR review for Interativa-group via workflow_call + deploy script.
EOF
)"

git push origin "HEAD:$default_branch"
echo "Published to https://github.com/$FULL"
