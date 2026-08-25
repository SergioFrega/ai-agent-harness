#!/usr/bin/env bash
# montar-contexto.sh — monta um pacote de contexto portátil de uma frente,
# para colar em qualquer IA sem perder o estado do projeto.
#
# Uso:  ./scripts/montar-contexto.sh <frente>
# Ex.:  ./scripts/montar-contexto.sh schema-dados
#
# Gera "_pacote-<frente>.md" com, nesta ordem: AGENTS.md, _ai/PROJECT.md,
# _ai/NOW.md, _ai/WORKING.md (só se EM ANDAMENTO), o handoff da frente,
# o CONTEXTO.md da frente, a fonte de verdade do projeto (só se configurada
# como interna) e a nota de sessão mais recente da frente (se existir).

set -euo pipefail
cd "$(dirname "$0")/.."

command -v jq >/dev/null 2>&1 || { echo "ERRO: jq é necessário."; exit 1; }

FRENTE_ARG="${1:-}"
if [ -z "$FRENTE_ARG" ]; then
  echo "Uso: ./scripts/montar-contexto.sh <frente>"
  echo
  echo "Frentes disponíveis:"
  grep '^## ' _ai/FRONTS.md 2>/dev/null | sed 's/^## /  - /' || true
  exit 1
fi

[ -f "_ai/project.json" ] || { echo "ERRO: _ai/project.json não encontrado — projeto não parece ter o harness instalado."; exit 1; }

FRONTS_MODE="$(jq -r '.fronts_mode' _ai/project.json)"
FRONTS_DIR="$(jq -r '.fronts_dir' _ai/project.json)"
SOURCE_OF_TRUTH="$(jq -r '.source_of_truth' _ai/project.json)"

# resolve o diretório da frente (aceita nome curto, casa por substring case-insensitive)
if [ "$FRONTS_MODE" = "root-numbered" ]; then
  MATCHES=$(ls -d [0-9]*-*/ 2>/dev/null | sed 's#/##' | grep -i "$FRENTE_ARG" || true)
else
  MATCHES=$(ls -d "$FRONTS_DIR"/*/ 2>/dev/null | xargs -n1 basename 2>/dev/null | grep -i "$FRENTE_ARG" || true)
fi

N_MATCHES=$(echo "$MATCHES" | grep -c . || true)
if [ "$N_MATCHES" -eq 0 ]; then
  echo "Frente '$FRENTE_ARG' não encontrada."
  exit 1
elif [ "$N_MATCHES" -gt 1 ]; then
  echo "'$FRENTE_ARG' casa mais de uma frente:"
  echo "$MATCHES" | sed 's/^/  - /'
  echo "Seja mais específico."
  exit 1
fi

DIR_NOME="$MATCHES"
if [ "$FRONTS_MODE" = "root-numbered" ]; then
  SLUG="${DIR_NOME#*-}"
  FRENTE_PATH="$DIR_NOME"
else
  SLUG="$DIR_NOME"
  FRENTE_PATH="$FRONTS_DIR/$DIR_NOME"
fi

HANDOFF="_ai/handoffs/${SLUG}.md"
OUT="_pacote-${SLUG}.md"

# _ai/WORKING.md só entra no pacote se representar trabalho ainda aberto
INCLUIR_WORKING=""
if [ -f "_ai/WORKING.md" ]; then
  STATUS_WORKING=$(awk '/^## Status$/{found=1; next} found && NF {print; exit}' "_ai/WORKING.md" 2>/dev/null || true)
  STATUS_WORKING="${STATUS_WORKING%.}"
  [ "$STATUS_WORKING" = "EM ANDAMENTO" ] && INCLUIR_WORKING="1"
fi

{
  echo "<!-- PACOTE DE CONTEXTO PORTÁTIL — gerado em $(date '+%Y-%m-%d %H:%M') -->"
  echo "<!-- Cole este arquivo inteiro no início de um chat com qualquer IA. -->"
  echo

  echo "# ANEXO: AGENTS.md (protocolo compartilhado)"
  echo
  cat AGENTS.md
  echo; echo "---"; echo

  if [ -f "_ai/PROJECT.md" ]; then
    echo "# ANEXO: _ai/PROJECT.md (contexto e regras do projeto)"
    echo
    cat "_ai/PROJECT.md"
    echo; echo "---"; echo
  fi

  if [ -f "_ai/NOW.md" ]; then
    echo "# ANEXO: _ai/NOW.md (estado atual do projeto)"
    echo
    cat "_ai/NOW.md"
    echo; echo "---"; echo
  fi

  if [ -n "$INCLUIR_WORKING" ]; then
    echo "# ANEXO: _ai/WORKING.md (checkpoint vivo — status EM ANDAMENTO)"
    echo "> Há trabalho em aberto registrado. Trate como estado provisório, não como decisão oficial."
    echo
    cat "_ai/WORKING.md"
    echo; echo "---"; echo
  fi

  if [ -f "$HANDOFF" ]; then
    echo "# ANEXO: HANDOFF DA FRENTE (${HANDOFF})"
    echo
    cat "$HANDOFF"
    echo; echo "---"; echo
  fi

  echo "# CONTEXTO DA FRENTE (${FRENTE_PATH}/CONTEXTO.md)"
  echo
  cat "${FRENTE_PATH}/CONTEXTO.md"

  if [[ "$SOURCE_OF_TRUTH" == internal:* ]]; then
    SOT_PATH="${SOURCE_OF_TRUTH#internal:}"
    if [ -f "$SOT_PATH" ]; then
      echo; echo "---"; echo
      echo "# ANEXO: FONTE DE VERDADE DO PROJETO (${SOT_PATH})"
      echo
      cat "$SOT_PATH"
    fi
  fi

  ULTIMA_SESSAO=$(ls -t "${FRENTE_PATH}"/sessao-*.md 2>/dev/null | head -1 || true)
  if [ -n "$ULTIMA_SESSAO" ]; then
    echo; echo "---"; echo
    echo "# ANEXO: NOTA DE SESSÃO EM ANDAMENTO (raciocínio ainda NÃO oficial)"
    echo "> Ainda NÃO virou decisão oficial — trate como contexto de trabalho em curso. Arquivo: ${ULTIMA_SESSAO}"
    echo
    cat "$ULTIMA_SESSAO"
  fi
} > "$OUT"

echo "Pacote gerado: $OUT"
echo "  -> Frente: ${SLUG}"
[ -n "$INCLUIR_WORKING" ] && echo "  -> Inclui _ai/WORKING.md (EM ANDAMENTO)."
[ -f "$HANDOFF" ] || echo "  -> AVISO: handoff ${HANDOFF} não existe ainda."
exit 0
