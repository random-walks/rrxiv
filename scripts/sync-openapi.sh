#!/usr/bin/env bash
# sync-openapi.sh — refresh schema/api.openapi.yaml from the reference server.
#
# The canonical OpenAPI is GENERATED from the FastAPI reference server in
# rrxiv-python (its scripts/dump_openapi.py). The server is the single source
# of truth for the API surface; this file is a synced artifact, not
# hand-edited. Run this after the server's routes change (and rrxiv-python's
# CI has regenerated its committed openapi.yaml).
#
# Usage: ./scripts/sync-openapi.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Find a sibling rrxiv-python checkout (workspace layouts vary).
for candidate in \
  "$REPO_ROOT/../rrxiv-python/openapi.yaml" \
  "$REPO_ROOT/../../rrxiv-python/openapi.yaml" \
  "$REPO_ROOT/../../repos/rrxiv-python/openapi.yaml"; do
  if [[ -f "$candidate" ]]; then
    SRC="$candidate"
    break
  fi
done

if [[ -z "${SRC:-}" ]]; then
  echo "ERROR: could not find rrxiv-python/openapi.yaml near $REPO_ROOT" >&2
  echo "Generate it first (in a rrxiv-python checkout):" >&2
  echo "  python scripts/dump_openapi.py" >&2
  exit 2
fi

cp "$SRC" "$REPO_ROOT/schema/api.openapi.yaml"
echo "synced schema/api.openapi.yaml from $SRC"
