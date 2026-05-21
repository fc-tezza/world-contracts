#!/usr/bin/env bash
# Point sui client at the local validator started with `sui start`.
set -euo pipefail
sui client new-env --alias localnet --rpc "http://127.0.0.1:9000" 2>/dev/null || true
sui client switch --env localnet
echo "Active env: $(sui client active-env)"
echo "Active address: $(sui client active-address)"
