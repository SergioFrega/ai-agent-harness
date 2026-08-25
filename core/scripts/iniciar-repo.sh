#!/usr/bin/env bash
# iniciar-repo.sh — inicia o repositório Git e faz o primeiro commit.
# Rode manualmente quando quiser, na raiz do projeto. Nunca é chamado
# automaticamente por install.sh/update.sh.

set -euo pipefail
cd "$(dirname "$0")/.."

if [ -d .git ]; then
  echo "Repo git já iniciado."
  exit 0
fi

git init -q
git branch -M main 2>/dev/null || true

if [ ! -f .gitignore ]; then
  cat > .gitignore <<'EOF'
_pacote-*.md
*.tmp
.DS_Store
EOF
else
  grep -qxF '_pacote-*.md' .gitignore || echo '_pacote-*.md' >> .gitignore
  grep -qxF '*.tmp' .gitignore || echo '*.tmp' >> .gitignore
  grep -qxF '.DS_Store' .gitignore || echo '.DS_Store' >> .gitignore
fi

git add .
git commit -q -m "estrutura inicial do projeto (ai-agent-harness)"
echo "Repo git iniciado e primeiro commit feito."
