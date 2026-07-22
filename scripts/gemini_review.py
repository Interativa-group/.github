#!/usr/bin/env python3
"""Generate a Gemini PR review and write it to GITHUB_OUTPUT."""

from __future__ import annotations

import json
import os
import urllib.error
import urllib.request


def main() -> None:
    api_key = os.environ["GEMINI_API_KEY"]
    model = os.environ.get("GEMINI_MODEL", "gemini-2.0-flash")
    language = os.environ.get("REVIEW_LANGUAGE", "pt-BR")
    title = os.environ.get("PR_TITLE") or ""
    body = os.environ.get("PR_BODY") or ""
    diff_file = os.environ.get("PR_DIFF_FILE") or ""
    repo = os.environ.get("REPO") or ""
    pr_number = os.environ.get("PR_NUMBER") or ""

    with open(diff_file, encoding="utf-8", errors="replace") as handle:
        diff = handle.read()

    prompt = "\n".join(
        [
            "Você é um revisor de código sênior da organização Interativa-group.",
            f"Revise o pull request abaixo e responda em {language}.",
            "",
            f"Repositório: {repo}",
            f"PR #{pr_number}",
            f"Título: {title}",
            "",
            "Descrição:",
            body,
            "",
            "Diff:",
            "```diff",
            diff,
            "```",
            "",
            "Instruções:",
            "1. Foque em bugs reais, regressões e problemas de lógica.",
            "2. Avalie qualidade (legibilidade, tipagem, testes, manutenibilidade).",
            "3. Verifique segurança (SQL injection, XSS, vazamento de secrets, authz/authn).",
            "4. Ignore estilo cosmético e arquivos gerados.",
            "5. Seja conciso e objetivo. Formate a resposta em markdown.",
            "6. Estruture assim:",
            "   - Resumo",
            "   - Problemas encontrados (se houver), com severidade",
            "   - Sugestões de melhoria",
            "   - Conclusão (aprovar com ressalvas / precisa ajustes / ok)",
        ]
    )

    url = (
        "https://generativelanguage.googleapis.com/v1beta/models/"
        f"{model}:generateContent?key={api_key}"
    )
    payload = {
        "contents": [{"parts": [{"text": prompt}]}],
        "generationConfig": {
            "temperature": 0.2,
            "maxOutputTokens": 4096,
        },
    }

    request = urllib.request.Request(
        url,
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST",
    )

    try:
        with urllib.request.urlopen(request, timeout=120) as response:
            data = json.load(response)
    except urllib.error.HTTPError as exc:
        err_body = exc.read().decode("utf-8", errors="replace")
        raise SystemExit(f"Gemini API error {exc.code}: {err_body}") from exc

    candidates = data.get("candidates") or []
    if not candidates:
        raise SystemExit(f"Gemini returned no candidates: {json.dumps(data)[:2000]}")

    parts = (((candidates[0] or {}).get("content") or {}).get("parts")) or []
    text = "\n".join(
        part.get("text", "") for part in parts if isinstance(part, dict)
    ).strip()
    if not text:
        raise SystemExit("Gemini returned empty review text")

    review = (
        "## Interativa AI Code Review\n\n"
        f"{text}"
        "\n\n---\n"
        f"_Modelo: `{model}` · gerado automaticamente em cada atualização da PR._"
    )

    out_path = os.environ["GITHUB_OUTPUT"]
    with open(out_path, "a", encoding="utf-8") as handle:
        handle.write("review<<EOF_REVIEW\n")
        handle.write(review)
        handle.write("\nEOF_REVIEW\n")


if __name__ == "__main__":
    main()
