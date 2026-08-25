#!/usr/bin/env bash
# atualizar-fonte-verdade.sh — carimba a data e commita a fonte de verdade
# do projeto, quando _ai/project.json define uma fonte interna. Módulo
# opcional: se source_of_truth for "none" ou "external:...", não faz nada
# além de informar.
#
# Uso:  ./scripts/atualizar-fonte-verdade.sh "descrição do que mudou"

set -euo pipefail
cd "$(dirname "$0")/.."

command -v jq >/dev/null 2>&1 || { echo "ERRO: jq é necessário."; exit 1; }
[ -f "_ai/project.json" ] || { echo "ERRO: _ai/project.json não encontrado."; exit 1; }

MSG="${1:-atualização da fonte de verdade}"
SOT="$(jq -r '.source_of_truth' _ai/project.json)"

case "$SOT" in
  none|"")
    echo "Nenhuma fonte de verdade interna configurada (_ai/project.json: source_of_truth=none). Nada a fazer."
    exit 0
    ;;
  internal:*)
    DOC="${SOT#internal:}"
    if [ ! -f "$DOC" ]; then
      echo "ERRO: fonte de verdade configurada como '$DOC', mas o arquivo não existe."
      exit 1
    fi
    HOJE="$(date '+%Y-%m-%d')"
    if grep -q "Última atualização:" "$DOC"; then
      sed -i.bak "s/\*\*Última atualização:\*\*.*/\*\*Última atualização:\*\* ${HOJE}/" "$DOC"
      rm -f "${DOC}.bak"
    fi
    if [ -d .git ]; then
      git add "$DOC"
      git commit -m "fonte de verdade: ${MSG} (${HOJE})" || echo "(nada mudou para commitar)"
      echo "Fonte de verdade atualizada e commitada: ${MSG}"
    else
      echo "Fonte de verdade atualizada (${HOJE}). Repo git não iniciado — rode ./scripts/iniciar-repo.sh se quiser versionar."
    fi
    ;;
  external:*)
    echo "Fonte de verdade é externa (${SOT#external:}) — nada a fazer localmente."
    ;;
  *)
    echo "AVISO: valor inesperado em source_of_truth ('$SOT'). Nada feito."
    ;;
esac
