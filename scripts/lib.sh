#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GENERATED_DIR="$ROOT_DIR/generated"
RUNTIME_EVIDENCE_DIR="$ROOT_DIR/evidence/runtime"

mkdir -p "$GENERATED_DIR" "$RUNTIME_EVIDENCE_DIR"

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1" >&2
    exit 1
  }
}

require_env() {
  local var="$1"
  local value="${!var:-}"
  [[ -n "$value" && "$value" != REPLACE_WITH_* ]] || {
    echo "Missing or unconfigured env var: $var (see docs/configuration.md)" >&2
    exit 1
  }
}
