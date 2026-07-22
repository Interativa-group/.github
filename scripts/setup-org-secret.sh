#!/usr/bin/env bash
# Set org-level GEMINI_CODE_REVIEW_API secret for Interativa-group.
# Usage:
#   GEMINI_CODE_REVIEW_API='your-key' ./scripts/setup-org-secret.sh
#   ./scripts/setup-org-secret.sh   # prompts securely if env unset

set -euo pipefail

ORG="${ORG:-Interativa-group}"
SECRET_NAME="${SECRET_NAME:-GEMINI_CODE_REVIEW_API}"

if [[ -z "${GEMINI_CODE_REVIEW_API:-}" ]]; then
  if [[ -t 0 ]]; then
    read -r -s -p "Cole a chave Gemini (GEMINI_CODE_REVIEW_API): " GEMINI_CODE_REVIEW_API
    echo
  else
    echo "Defina GEMINI_CODE_REVIEW_API no ambiente ou rode interativamente." >&2
    echo
    echo "Alternativa via UI (se o token gh não tiver escopo de secrets da org):" >&2
    echo "  https://github.com/organizations/${ORG}/settings/secrets/actions" >&2
    echo "  New organization secret → name: ${SECRET_NAME} → Repository access: All repositories" >&2
    exit 1
  fi
fi

if [[ -z "${GEMINI_CODE_REVIEW_API}" ]]; then
  echo "Chave vazia; abortando." >&2
  exit 1
fi

echo "Definindo secret org ${ORG}/${SECRET_NAME} (visibility=all)..."
if gh secret set "$SECRET_NAME" --org "$ORG" --visibility all --body "$GEMINI_CODE_REVIEW_API"; then
  echo "OK: secret configurado na organização."
  exit 0
fi

echo
echo "Falha via API (token precisa de admin:org / Actions secrets)." >&2
echo "Configure manualmente:" >&2
echo "  1. Abra https://github.com/organizations/${ORG}/settings/secrets/actions" >&2
echo "  2. New organization secret" >&2
echo "  3. Name: ${SECRET_NAME}" >&2
echo "  4. Value: <sua chave do https://aistudio.google.com/>" >&2
echo "  5. Repository access: All repositories (ou a lista de repos do scripts/repos.txt)" >&2
echo
echo "Opcional — variável de organização GEMINI_MODEL=gemini-2.0-flash" >&2
exit 1
