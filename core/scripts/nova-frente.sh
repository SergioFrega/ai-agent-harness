#!/usr/bin/env bash
# nova-frente.sh — cria a estrutura mínima de uma frente nova com segurança:
# CONTEXTO.md, handoff em _ai/handoffs/ e entrada em _ai/FRONTS.md.
#
# Uso:  ./scripts/nova-frente.sh <slug> "<descrição de uma linha>"
# Ex.:  ./scripts/nova-frente.sh schema-dados "Schema e catálogo de produto."
#
# Regra do protocolo (AGENTS.md): só rode este script sob pedido explícito
# do usuário, e só depois de confirmar que o assunto não pertence a uma
# frente já existente — esse julgamento é do agente, não deste script.

set -euo pipefail
cd "$(dirname "$0")/.."

command -v jq >/dev/null 2>&1 || { echo "ERRO: jq é necessário."; exit 1; }

SLUG="${1:-}"
DESCRICAO="${2:-(preencher)}"

if [ -z "$SLUG" ]; then
  echo "Uso: ./scripts/nova-frente.sh <slug> \"<descrição de uma linha>\""
  exit 1
fi

if ! echo "$SLUG" | grep -Eq '^[a-z0-9]+(-[a-z0-9]+)*$'; then
  echo "ERRO: slug inválido ('$SLUG'). Use apenas letras minúsculas, números e hífen (ex.: schema-dados)."
  exit 1
fi

[ -f "_ai/project.json" ] || { echo "ERRO: _ai/project.json não encontrado — projeto não parece ter o harness instalado."; exit 1; }
[ -f "_ai/FRONTS.md" ] || { echo "ERRO: _ai/FRONTS.md não encontrado."; exit 1; }

FRONTS_MODE="$(jq -r '.fronts_mode' _ai/project.json)"
FRONTS_DIR="$(jq -r '.fronts_dir' _ai/project.json)"

TPL_CONTEXTO="_ai/templates/CONTEXTO.md.tpl"
TPL_HANDOFF="_ai/templates/handoff.md.tpl"
[ -f "$TPL_CONTEXTO" ] || { echo "ERRO: template $TPL_CONTEXTO ausente."; exit 1; }
[ -f "$TPL_HANDOFF" ] || { echo "ERRO: template $TPL_HANDOFF ausente."; exit 1; }

# checa colisão em _ai/FRONTS.md (case-insensitive, por heading, com ou sem prefixo numérico)
if grep -qiE "^## ([0-9]{2}-)?${SLUG}\$" _ai/FRONTS.md; then
  echo "ERRO: já existe uma entrada para '${SLUG}' em _ai/FRONTS.md. Nada foi criado."
  exit 1
fi

if [ "$FRONTS_MODE" = "root-numbered" ]; then
  if ls -d [0-9][0-9]-"$SLUG" >/dev/null 2>&1; then
    echo "ERRO: diretório para '${SLUG}' já existe. Nada foi criado."
    exit 1
  fi
  LAST_NUM=$(ls -d [0-9][0-9]-*/ 2>/dev/null | sed -E 's/^([0-9]{2})-.*/\1/' | sort -n | tail -1 || true)
  [ -z "$LAST_NUM" ] && LAST_NUM=0
  NEXT_NUM=$(printf "%02d" $((10#$LAST_NUM + 1)))
  FRENTE_DIR="${NEXT_NUM}-${SLUG}"
  HEADING="${NEXT_NUM}-${SLUG}"
else
  if [ -d "${FRONTS_DIR}/${SLUG}" ]; then
    echo "ERRO: diretório ${FRONTS_DIR}/${SLUG} já existe. Nada foi criado."
    exit 1
  fi
  FRENTE_DIR="${FRONTS_DIR}/${SLUG}"
  HEADING="${SLUG}"
fi

mkdir -p "$FRENTE_DIR"

sed -e "s|{{FRONTE_NOME}}|${SLUG}|g" \
    -e "s|{{FRONTE_SLUG}}|${SLUG}|g" \
    -e "s|{{DESCRICAO}}|${DESCRICAO}|g" \
    "$TPL_CONTEXTO" > "${FRENTE_DIR}/CONTEXTO.md"

mkdir -p "_ai/handoffs"
sed -e "s|{{FRONTE_NOME}}|${SLUG}|g" \
    "$TPL_HANDOFF" > "_ai/handoffs/${SLUG}.md"

# atualiza _ai/FRONTS.md — remove o placeholder "nenhuma frente" se existir,
# depois adiciona a entrada nova só por append (nunca reescreve linhas existentes)
if grep -q "^(nenhuma frente criada" _ai/FRONTS.md; then
  grep -v "^(nenhuma frente criada" _ai/FRONTS.md > _ai/FRONTS.md.tmp && mv _ai/FRONTS.md.tmp _ai/FRONTS.md
fi
{
  echo
  echo "## ${HEADING}"
  echo "${DESCRICAO}"
} >> _ai/FRONTS.md

echo "Frente criada: ${FRENTE_DIR}"
echo "  -> ${FRENTE_DIR}/CONTEXTO.md"
echo "  -> _ai/handoffs/${SLUG}.md"
echo "  -> _ai/FRONTS.md atualizado (entrada '${HEADING}' adicionada)"
echo
echo "Nada foi commitado. _ai/NOW.md não foi alterado (atualize manualmente se esta virar a frente ativa)."
