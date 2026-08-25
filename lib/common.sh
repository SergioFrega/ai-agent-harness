#!/usr/bin/env bash
# lib/common.sh — funções compartilhadas por install.sh e update.sh.
# Não é copiado para projetos instalados; vive só neste repositório.

require_jq() {
  command -v jq >/dev/null 2>&1 || {
    echo "ERRO: 'jq' é necessário e não foi encontrado no PATH." >&2
    echo "Instale com 'brew install jq' (macOS) ou o gerenciador de pacotes do seu sistema." >&2
    exit 1
  }
}

sha256_of() {
  local f="$1"
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$f" | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$f" | awk '{print $1}'
  else
    echo "ERRO: nem 'shasum' nem 'sha256sum' encontrados." >&2
    exit 1
  fi
}

iso_now() {
  local base tz
  base="$(date '+%Y-%m-%dT%H:%M:%S')"
  tz="$(date '+%z')"
  echo "${base}$(echo "$tz" | sed -E 's/([+-][0-9]{2})([0-9]{2})/\1:\2/')"
}

harness_version() {
  local harness_dir="$1"
  tr -d '[:space:]' < "$harness_dir/VERSION"
}

# Lista os caminhos (relativos a core/) de todos os arquivos harness-owned
# que vêm de core/. Um por linha, ordenados.
core_owned_files() {
  local harness_dir="$1"
  (cd "$harness_dir/core" && find . -type f | sed 's#^\./##' | sort)
}
