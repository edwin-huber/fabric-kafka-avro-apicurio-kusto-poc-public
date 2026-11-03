#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"

require_cmd docker
require_cmd az
require_cmd jq
require_cmd curl

echo "Tooling OK"
az account show --output json | jq '{tenantId, id, name, user}'
