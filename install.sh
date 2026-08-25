#!/usr/bin/env bash
# install.sh — instala o ai-agent-harness num projeto novo ou existente.
#
# Uso:
#   ./install.sh <caminho-do-projeto> [opções]
#
# Opções:
#   --name "Nome do Projeto"
#   --agents codex,claude-code
#   --fronts-mode ai-fronts|root-numbered   (default: ai-fronts)
#   --source-of-truth none|internal:<path>|external:<descrição>  (default: none)
#   --yes        assume os defaults para o que não foi passado por flag,
#                sem perguntar interativamente
#
# Nunca sobrescreve AGENTS.md/CLAUDE.md existentes sem confirmar — o
# conteúdo anterior é sempre migrado para _ai/PROJECT.md antes de qualquer
# escrita. Nunca faz git init/commit.

set -euo pipefail
HARNESS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$HARNESS_DIR/lib/common.sh"
require_jq

usage() {
  cat <<EOF
Uso: ./install.sh <caminho-do-projeto> [--name NOME] [--agents a,b] \\
       [--fronts-mode ai-fronts|root-numbered] \\
       [--source-of-truth none|internal:<path>|external:<desc>] [--yes]
EOF
}

TARGET_ARG="${1:-}"
[ -z "$TARGET_ARG" ] && { usage; exit 1; }
shift || true

NAME=""
AGENTS="codex,claude-code"
FRONTS_MODE="ai-fronts"
SOURCE_OF_TRUTH="none"
ASSUME_YES=0

while [ $# -gt 0 ]; do
  case "$1" in
    --name) NAME="$2"; shift 2 ;;
    --agents) AGENTS="$2"; shift 2 ;;
    --fronts-mode) FRONTS_MODE="$2"; shift 2 ;;
    --source-of-truth) SOURCE_OF_TRUTH="$2"; shift 2 ;;
    --yes) ASSUME_YES=1; shift ;;
    *) echo "Opção desconhecida: $1"; usage; exit 1 ;;
  esac
done

if [ "$FRONTS_MODE" != "ai-fronts" ] && [ "$FRONTS_MODE" != "root-numbered" ]; then
  echo "ERRO: --fronts-mode deve ser 'ai-fronts' ou 'root-numbered'."
  exit 1
fi

mkdir -p "$TARGET_ARG"
TARGET="$(cd "$TARGET_ARG" && pwd)"

[ -z "$NAME" ] && NAME="$(basename "$TARGET")"

echo "Instalando ai-agent-harness $(harness_version "$HARNESS_DIR") em: $TARGET"

if [ -f "$TARGET/_ai/harness.json" ]; then
  echo "ERRO: $TARGET já tem o harness instalado (_ai/harness.json existe). Use ./update.sh em vez de install.sh."
  exit 1
fi

LEGACY_CONTENT=""
LEGACY_FOUND=0
if [ -f "$TARGET/AGENTS.md" ]; then
  LEGACY_FOUND=1
  LEGACY_CONTENT="${LEGACY_CONTENT}"$'\n'"### Conteúdo herdado de AGENTS.md"$'\n\n'"$(cat "$TARGET/AGENTS.md")"$'\n'
fi
if [ -f "$TARGET/CLAUDE.md" ] && [ "$(cat "$TARGET/CLAUDE.md")" != "@AGENTS.md" ]; then
  LEGACY_FOUND=1
  LEGACY_CONTENT="${LEGACY_CONTENT}"$'\n'"### Conteúdo herdado de CLAUDE.md"$'\n\n'"$(cat "$TARGET/CLAUDE.md")"$'\n'
fi

if [ "$LEGACY_FOUND" -eq 1 ]; then
  echo
  echo "AVISO: encontrado AGENTS.md e/ou CLAUDE.md pré-existente em $TARGET."
  echo "O conteúdo será migrado integralmente para _ai/PROJECT.md antes de qualquer sobrescrita."
  if [ "$ASSUME_YES" -ne 1 ]; then
    read -r -p "Confirma prosseguir e sobrescrever AGENTS.md/CLAUDE.md com a versão do harness? [s/N] " ANS
    case "$ANS" in
      s|S) : ;;
      *) echo "Instalação abortada. Nada foi alterado."; exit 1 ;;
    esac
  fi
fi

FRONTS_DIR="_ai/fronts"
[ "$FRONTS_MODE" = "root-numbered" ] && FRONTS_DIR="."

mkdir -p "$TARGET/_ai/handoffs" "$TARGET/_ai/templates" "$TARGET/scripts"
[ "$FRONTS_MODE" = "ai-fronts" ] && mkdir -p "$TARGET/$FRONTS_DIR"

# copia todos os arquivos harness-owned de core/
while IFS= read -r rel; do
  mkdir -p "$TARGET/$(dirname "$rel")"
  cp "$HARNESS_DIR/core/$rel" "$TARGET/$rel"
  case "$rel" in scripts/*.sh) chmod +x "$TARGET/$rel" ;; esac
done < <(core_owned_files "$HARNESS_DIR")

cp "$HARNESS_DIR/templates/CONTEXTO.md.tpl" "$TARGET/_ai/templates/CONTEXTO.md.tpl"
cp "$HARNESS_DIR/templates/handoff.md.tpl" "$TARGET/_ai/templates/handoff.md.tpl"

case "$FRONTS_MODE" in
  root-numbered) FRONTS_MODE_LABEL="pastas numeradas na raiz do projeto" ;;
  *) FRONTS_MODE_LABEL="pasta própria dentro de _ai/fronts/" ;;
esac
case "$SOURCE_OF_TRUTH" in
  none) SOT_LABEL="nenhuma (não configurada)" ;;
  internal:*) SOT_LABEL="documento interno: ${SOURCE_OF_TRUTH#internal:}" ;;
  external:*) SOT_LABEL="externa: ${SOURCE_OF_TRUTH#external:}" ;;
  *) SOT_LABEL="$SOURCE_OF_TRUTH" ;;
esac

sed -e "s|{{PROJECT_NAME}}|$NAME|g" \
    -e "s|{{AGENTS_LIST}}|$AGENTS|g" \
    -e "s|{{FRONTS_DIR}}|$FRONTS_DIR|g" \
    -e "s|{{FRONTS_MODE_LABEL}}|$FRONTS_MODE_LABEL|g" \
    -e "s|{{SOURCE_OF_TRUTH_LABEL}}|$SOT_LABEL|g" \
    "$HARNESS_DIR/templates/PROJECT.md.tpl" > "$TARGET/_ai/PROJECT.md"

if [ -n "$LEGACY_CONTENT" ]; then
  {
    echo
    echo "## Conteúdo herdado (migrado automaticamente na instalação)"
    echo
    echo "$LEGACY_CONTENT"
  } >> "$TARGET/_ai/PROJECT.md"
fi

INSTALL_DATE="$(date '+%Y-%m-%d')"
INSTALL_TS="$(iso_now)"
sed -e "s|{{INSTALL_DATE}}|$INSTALL_DATE|g" "$HARNESS_DIR/templates/NOW.md.tpl" > "$TARGET/_ai/NOW.md"
sed -e "s|{{INSTALL_TIMESTAMP}}|$INSTALL_TS|g" "$HARNESS_DIR/templates/WORKING.md.tpl" > "$TARGET/_ai/WORKING.md"
cp "$HARNESS_DIR/templates/FRONTS.md.tpl" "$TARGET/_ai/FRONTS.md"

AGENTS_JSON_ARR="$(printf '%s\n' "${AGENTS//,/$'\n'}" | jq -R . | jq -s .)"
jq -n \
  --arg name "$NAME" \
  --argjson agents "$AGENTS_JSON_ARR" \
  --arg fmode "$FRONTS_MODE" \
  --arg fdir "$FRONTS_DIR" \
  --arg sot "$SOURCE_OF_TRUTH" \
  '{project_name:$name, agents:$agents, fronts_mode:$fmode, fronts_dir:$fdir, source_of_truth:$sot}' \
  > "$TARGET/_ai/project.json"

VERSION_NUM="$(harness_version "$HARNESS_DIR")"
FILES_JSON="[]"
while IFS= read -r rel; do
  h="$(sha256_of "$TARGET/$rel")"
  FILES_JSON="$(echo "$FILES_JSON" | jq --arg p "$rel" --arg h "$h" --arg v "$VERSION_NUM" '. + [{path:$p, sha256:$h, synced_version:$v, status:"synced"}]')"
done < <(core_owned_files "$HARNESS_DIR")
for extra in "_ai/templates/CONTEXTO.md.tpl" "_ai/templates/handoff.md.tpl"; do
  h="$(sha256_of "$TARGET/$extra")"
  FILES_JSON="$(echo "$FILES_JSON" | jq --arg p "$extra" --arg h "$h" --arg v "$VERSION_NUM" '. + [{path:$p, sha256:$h, synced_version:$v, status:"synced"}]')"
done

jq -n \
  --arg hp "$HARNESS_DIR" \
  --arg iv "$VERSION_NUM" \
  --arg tv "$VERSION_NUM" \
  --arg us "complete" \
  --arg ts "$INSTALL_TS" \
  --argjson files "$FILES_JSON" \
  '{harness_source_path:$hp, installed_version:$iv, target_version:$tv, update_status:$us, last_checked_at:$ts, files:$files}' \
  > "$TARGET/_ai/harness.json"

echo
echo "Instalação concluída em: $TARGET"
echo "  -> Modo de frentes: $FRONTS_MODE ($FRONTS_DIR)"
echo "  -> Fonte de verdade: $SOURCE_OF_TRUTH"
[ -n "$LEGACY_CONTENT" ] && echo "  -> Conteúdo anterior de AGENTS.md/CLAUDE.md migrado para _ai/PROJECT.md — revise."
echo
echo "Próximos passos:"
echo "  - Revisar _ai/PROJECT.md"
echo "  - (opcional) ./scripts/iniciar-repo.sh para iniciar o Git"
echo "  - ./scripts/nova-frente.sh <slug> \"<descrição>\" para criar a primeira frente"
