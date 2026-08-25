#!/usr/bin/env bash
# update.sh — sincroniza os arquivos harness-owned de um projeto já instalado
# com a versão atual deste repositório do harness. Nunca sobrescreve arquivos
# project-owned (_ai/PROJECT.md, _ai/project.json, _ai/FRONTS.md, _ai/NOW.md,
# _ai/WORKING.md, _ai/handoffs/*, qualquer CONTEXTO.md de frente).
#
# Uso:
#   ./update.sh <caminho-do-projeto> [--force] [--harness-path <caminho>]
#
# Se um arquivo harness-owned foi editado localmente desde o último
# install/update, ele é preservado e marcado como pendente — a menos que
# --force seja passado. O projeto só é considerado totalmente atualizado
# (_ai/harness.json.update_status = "complete") quando todos os arquivos
# harness-owned aplicáveis estiverem sincronizados com a versão atual.

set -euo pipefail

TARGET_ARG="${1:-}"
[ -z "$TARGET_ARG" ] && { echo "Uso: ./update.sh <caminho-do-projeto> [--force] [--harness-path <caminho>]"; exit 1; }
shift || true

FORCE=0
HARNESS_OVERRIDE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --force) FORCE=1; shift ;;
    --harness-path) HARNESS_OVERRIDE="$2"; shift 2 ;;
    *) echo "Opção desconhecida: $1"; exit 1 ;;
  esac
done

DEFAULT_HARNESS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HARNESS_DIR="${HARNESS_OVERRIDE:-$DEFAULT_HARNESS_DIR}"
# shellcheck source=lib/common.sh
source "$HARNESS_DIR/lib/common.sh"
require_jq

[ -d "$TARGET_ARG" ] || { echo "ERRO: $TARGET_ARG não existe."; exit 1; }
TARGET="$(cd "$TARGET_ARG" && pwd)"

[ -f "$TARGET/_ai/harness.json" ] || { echo "ERRO: $TARGET não tem o harness instalado (_ai/harness.json ausente). Use ./install.sh."; exit 1; }

TARGET_VERSION="$(harness_version "$HARNESS_DIR")"
PREV_INSTALLED="$(jq -r '.installed_version' "$TARGET/_ai/harness.json")"

echo "Atualizando $TARGET (instalado: $PREV_INSTALLED, alvo: $TARGET_VERSION)..."

MAPPINGS=()
while IFS= read -r rel; do
  MAPPINGS+=("$HARNESS_DIR/core/$rel|$rel")
done < <(core_owned_files "$HARNESS_DIR")
MAPPINGS+=("$HARNESS_DIR/templates/CONTEXTO.md.tpl|_ai/templates/CONTEXTO.md.tpl")
MAPPINGS+=("$HARNESS_DIR/templates/handoff.md.tpl|_ai/templates/handoff.md.tpl")

ALL_SYNCED=1
FILES_JSON="[]"

for mapping in "${MAPPINGS[@]}"; do
  SRC="${mapping%%|*}"
  DEST_REL="${mapping##*|}"
  DEST="$TARGET/$DEST_REL"
  mkdir -p "$(dirname "$DEST")"

  PREV_HASH="$(jq -r --arg p "$DEST_REL" '.files[]? | select(.path==$p) | .sha256 // empty' "$TARGET/_ai/harness.json")"
  PREV_SYNCED_VER="$(jq -r --arg p "$DEST_REL" '.files[]? | select(.path==$p) | .synced_version // empty' "$TARGET/_ai/harness.json")"

  if [ ! -f "$DEST" ]; then
    cp "$SRC" "$DEST"
    case "$DEST_REL" in scripts/*.sh) chmod +x "$DEST" ;; esac
    STATUS="synced"; SYNCED_VER="$TARGET_VERSION"; NEW_HASH="$(sha256_of "$DEST")"
    echo "  novo:      $DEST_REL"
  else
    CUR_HASH="$(sha256_of "$DEST")"
    if [ -n "$PREV_HASH" ] && [ "$CUR_HASH" != "$PREV_HASH" ]; then
      if [ "$FORCE" -eq 1 ]; then
        cp "$SRC" "$DEST"
        case "$DEST_REL" in scripts/*.sh) chmod +x "$DEST" ;; esac
        STATUS="synced"; SYNCED_VER="$TARGET_VERSION"; NEW_HASH="$(sha256_of "$DEST")"
        echo "  forçado:   $DEST_REL (modificação local sobrescrita por --force)"
      else
        STATUS="modified_locally"; SYNCED_VER="$PREV_SYNCED_VER"; NEW_HASH="$PREV_HASH"
        echo "  pendente:  $DEST_REL (modificado localmente — use --force para sobrescrever)"
      fi
    else
      cp "$SRC" "$DEST"
      case "$DEST_REL" in scripts/*.sh) chmod +x "$DEST" ;; esac
      STATUS="synced"; SYNCED_VER="$TARGET_VERSION"; NEW_HASH="$(sha256_of "$DEST")"
      echo "  ok:        $DEST_REL"
    fi
  fi

  if [ "$STATUS" != "synced" ] || [ "$SYNCED_VER" != "$TARGET_VERSION" ]; then
    ALL_SYNCED=0
  fi

  FILES_JSON="$(echo "$FILES_JSON" | jq --arg p "$DEST_REL" --arg h "$NEW_HASH" --arg v "$SYNCED_VER" --arg s "$STATUS" '. + [{path:$p, sha256:$h, synced_version:$v, status:$s}]')"
done

if [ "$ALL_SYNCED" -eq 1 ]; then
  NEW_INSTALLED="$TARGET_VERSION"
  UPDATE_STATUS="complete"
else
  NEW_INSTALLED="$PREV_INSTALLED"
  UPDATE_STATUS="partial"
fi

TS="$(iso_now)"
jq -n \
  --arg hp "$HARNESS_DIR" \
  --arg iv "$NEW_INSTALLED" \
  --arg tv "$TARGET_VERSION" \
  --arg us "$UPDATE_STATUS" \
  --arg ts "$TS" \
  --argjson files "$FILES_JSON" \
  '{harness_source_path:$hp, installed_version:$iv, target_version:$tv, update_status:$us, last_checked_at:$ts, files:$files}' \
  > "$TARGET/_ai/harness.json.new"
mv "$TARGET/_ai/harness.json.new" "$TARGET/_ai/harness.json"

echo
echo "Update concluído. Status: $UPDATE_STATUS (instalado: $NEW_INSTALLED / alvo: $TARGET_VERSION)"
[ "$UPDATE_STATUS" = "partial" ] && echo "Há arquivos pendentes — rode novamente com --force se quiser forçar a sincronização."
exit 0
