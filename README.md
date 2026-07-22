# Interativa AI Code Review

Workflows reutilizáveis de code review com **Google Gemini** para a organização
[Interativa-group](https://github.com/Interativa-group).

Em toda PR (`opened` / `synchronize` / `reopened`), o caller do repositório
invoca o workflow central em `Interativa-group/.github` e publica (ou atualiza)
um comentário com o review.

## Arquitetura

```
Repo consumidor                         Org repo .github
─────────────────                       ────────────────
.github/workflows/                      .github/workflows/
  ai-review-caller.yaml  ──uses──►        ai-review.yaml
                                          slack.yaml (stub opcional)
```

## Pré-requisitos

1. Repo org **`Interativa-group/.github`** publicado (este projeto).
2. Secret de organização **`GEMINI_CODE_REVIEW_API`** (chave do
   [Google AI Studio](https://aistudio.google.com/)).
3. (Opcional) variável de organização **`GEMINI_MODEL`** — default
   `gemini-2.0-flash`.
4. Actions habilitadas nos repositórios consumidores; reusable workflows
   permitidos na org.

## Publicar o repo central

```bash
cd /root/projects/ai-code-review
# A estrutura de publicação coloca workflows em .github/workflows/
./scripts/publish-org-repo.sh   # ou siga o fluxo manual no README de deploy
```

Estrutura esperada no repositório `.github` da org:

```
.github/                 # root do repositório org
  workflows/
    ai-review.yaml
    slack.yaml
  profile/
    README.md
  README.md
```

## Deploy do caller nos repositórios

1. Edite [`scripts/repos.txt`](scripts/repos.txt) (um repo por linha).
2. Execute:

```bash
./scripts/deploy-review-workflow.sh
```

O script abre uma PR em cada repo adicionando
`.github/workflows/ai-review-caller.yaml`.

## Personalização do prompt

O prompt vive em [`workflows/ai-review.yaml`](workflows/ai-review.yaml).
Pontos principais:

1. Bugs e regressões
2. Qualidade e manutenibilidade
3. Segurança (SQL injection, XSS, secrets, auth)
4. Seja conciso e objetivo. Formate a resposta em markdown.

## Troubleshooting

### Workflow não aparece nos repositórios

1. Confirme o secret `GEMINI_CODE_REVIEW_API` na **organização**.
2. Repo `.github` deve ser **public** ou **internal**.
3. Verifique permissões do GitHub App / token e se Actions estão habilitadas.

### Review não é gerado

1. Veja os logs do workflow na aba Actions.
2. Confirme se a chave Gemini é válida.
3. Verifique o nome do modelo em `GEMINI_MODEL`.

### Secret org

```bash
# Requer escopo admin:org / secrets da organização
gh secret set GEMINI_CODE_REVIEW_API --org Interativa-group --visibility all
```

Se o token local não tiver permissão, configure em:
GitHub → Organization → Settings → Secrets and variables → Actions.

## Links úteis

- [Google AI Studio](https://aistudio.google.com/)
- [Reusable Workflows](https://docs.github.com/en/actions/using-workflows/reusing-workflows)
- [GitHub CLI](https://cli.github.com/)
